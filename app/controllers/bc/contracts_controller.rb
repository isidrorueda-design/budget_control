# frozen_string_literal: true
module Bc
  class ContractsController < ::BudgetControl::ApplicationController
    before_action :set_contract, only: %i[edit update destroy]
    before_action :set_selects, only: %i[new create edit update]

    def index
      scope = scoped_relation(BcContract)
      scope = scope.where(contractor_id: params[:contractor_id]) if params[:contractor_id].present?
      scope = scope.where(id: params[:contract_id]) if params[:contract_id].present?
      @contracts = scope.includes(:contractor, :item).order('bc_contracts.number ASC')

      # Calcula los totales para la fila de resumen
      @totals = {
        amount: @contracts.sum(&:amount),
        additives: @contracts.sum(&:additives),
        deductives: @contracts.sum(&:deductives),
        total_amount: @contracts.sum(&:total_amount),
        iva: @contracts.sum(&:iva),
        total_with_iva: @contracts.sum(&:total_with_iva),
        advance: @contracts.sum(&:advance)
      }

      @contractors_for_select = scoped_relation(BcContractor).order(:name)
      @contracts_for_select = params[:contractor_id].present? ? scoped_relation(BcContract).where(contractor_id: params[:contractor_id]).order(:number) : BcContract.none
    end

    def new
      @contract = @project.bc_contracts.build
    end

    def create
      @contract = @project.bc_contracts.build(contract_params)
      if @contract.save
        flash[:notice] = 'Contrato creado correctamente.'
        redirect_to bc_contracts_path(project_id: @project)
      else
        render :new
      end
    end

    def edit
      # @contract y @..._for_select ya están cargados por los before_action
    end

    def update
      if @contract.update(contract_params)
        flash[:notice] = 'Contrato actualizado correctamente.'
        redirect_to bc_contracts_path(project_id: @project)
      else
        render :edit
      end
    end

    def destroy
      if @contract.destroy
        flash[:notice] = 'Contrato eliminado correctamente.'
      else
        flash[:error] = @contract.errors.full_messages.to_sentence
      end
      redirect_to bc_contracts_path(project_id: @project)
    end

    # ⬇️ EXPORTAR contratos a Excel
    def export
      @contracts = scoped_relation(BcContract).includes(:contractor, :item).order('bc_contracts.number ASC')
      respond_to do |format|
        format.xlsx {
          response.headers['Content-Disposition'] = "attachment; filename=\"contratos_#{@project.identifier}_#{Time.now.strftime('%Y%m%d')}.xlsx\""
        }
      end
    end

    # ⬇️ IMPORTAR contratos desde Excel
    def import
      file = params[:file]
      unless file && file.content_type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        flash[:error] = 'Por favor, sube un archivo XLSX válido.'
        redirect_to bc_contracts_path(project_id: @project) and return
      end

      imported_count = 0
      updated_count = 0
      failed_rows    = []

      begin
        spreadsheet = Roo::Excelx.new(file.path)
        header = spreadsheet.row(1).map { |h| h.to_s.strip }

        expected_headers = ['Número', 'Contratista', 'Partida', 'Monto']
        unless expected_headers.all? { |h| header.map(&:downcase).include?(h.downcase) }
          flash[:error] = "El archivo Excel no contiene todas las columnas esperadas. Se requieren: #{expected_headers.join(', ')}."
          redirect_to bc_contracts_path(project_id: @project) and return
        end

        header_map = {
          'número'      => :number,
          'contratista' => :contractor_id,
          'partida'     => :item_id,
          'monto'       => :amount,
          'aditivas'    => :additives,
          'deductivas'  => :deductives,
          'anticipo'    => :advance,
          'inicio'      => :start_date,
          'fin'         => :end_date,
          'aplicar iva' => :apply_iva
        }

        (2..spreadsheet.last_row).each do |i|
          row = Hash[header.zip(spreadsheet.row(i).map(&:to_s))]
          row_data_normalized = row.transform_keys { |k| k.to_s.downcase.strip }

          contract_number = row_data_normalized['número'].to_s.strip
          unless contract_number.present?
            failed_rows << "Fila #{i}: El número de contrato no puede estar vacío."
            next
          end

          contractor_name = row_data_normalized['contratista'].to_s.strip
          item_code = row_data_normalized['partida'].to_s.strip

          unless contractor_name.present? && item_code.present?
            failed_rows << "Fila #{i}: El nombre del contratista y el código de la partida son obligatorios."
            next
          end

          contractor = @project.bc_contractors.find_by(name: contractor_name)
          item = @project.bc_items.find_by(description: item_code) # <-- CAMBIO: Buscar por descripción en lugar de código

          unless contractor && item
            missing = []
            missing << "Contratista '#{contractor_name}'" unless contractor
            missing << "Partida '#{item_code}'" unless item # El error ahora reflejará que no se encontró la descripción
            failed_rows << "Fila #{i}: No se encontró #{missing.join(' ni ')}. Deben existir en el sistema antes de importar contratos."
            next
          end

          contract = @project.bc_contracts.find_or_initialize_by(number: contract_number)
          is_new_record = contract.new_record?

          # Función helper para limpiar valores numéricos (moneda)
          clean_currency = ->(value) {
            value.to_s.gsub(/[$,]/, '').tr('.', ',').sub(',', '.').to_f
          }

          contract_attrs = {
            contractor_id: contractor.id,
            item_id:       item.id,
            # Usamos la función de limpieza para los campos de moneda
            amount:        clean_currency.call(row_data_normalized['monto']),
            additives:     clean_currency.call(row_data_normalized['aditivas']),
            deductives:    clean_currency.call(row_data_normalized['deductivas']),
            advance:       clean_currency.call(row_data_normalized['anticipo']),
            apply_iva:     ['true', 'si', 'sí', '1'].include?(row_data_normalized['aplicar iva'].to_s.downcase)
          }
          contract_attrs[:start_date] = Date.parse(row_data_normalized['inicio']) rescue nil if row_data_normalized['inicio'].present?
          contract_attrs[:end_date] = Date.parse(row_data_normalized['fin']) rescue nil if row_data_normalized['fin'].present?

          contract.assign_attributes(contract_attrs)

          if contract.save
            if is_new_record
              imported_count += 1
            else
              updated_count += 1 if contract.previous_changes.any?
            end
          else
            failed_rows << "Fila #{i} (Contrato '#{contract_number}'): #{contract.errors.full_messages.to_sentence}"
          end
        end

        success_message = []
        success_message << "#{imported_count} contratos creados." if imported_count > 0
        success_message << "#{updated_count} contratos actualizados." if updated_count > 0
        flash[:notice] = success_message.join(' ') if success_message.any?

        if failed_rows.any?
          error_summary = "Se encontraron errores en la importación de #{failed_rows.count} filas."
          if failed_rows.count <= 3
            flash[:error] = "#{error_summary} Detalles: #{failed_rows.join('; ')}"
          else
            flash[:error] = "#{error_summary} Revisa los logs del servidor para ver todos los detalles."
          end
          Rails.logger.error "Errores de importación de contratos: \n#{failed_rows.join("\n")}"
        end

      rescue Roo::HeaderRowNotFoundError
        flash[:error] = "Error en el archivo Excel: No se encontró la fila de encabezado."
      rescue => e
        flash[:error] = "Error inesperado al importar el archivo: #{e.message}"
        Rails.logger.error "Import error in Bc::ContractsController: #{e.message}\n#{e.backtrace.join("\n")}"
      end

      redirect_to bc_contracts_path(project_id: @project)
    end

    private

    def contract_params
      params.require(:bc_contract).permit(:number, :contractor_id, :item_id, :amount,
                                        :additives, :deductives, :advance,
                                        :start_date, :end_date, :apply_iva)
    end

    def set_contract
      @contract = scoped_relation(BcContract).find(params[:id])
    end

    def set_selects
      @contractors_for_select = scoped_relation(BcContractor).order(:name)
      @items_for_select = scoped_relation(BcItem).order(:code)
    end
  end
end