# frozen_string_literal: true
module Bc
  class ContractorsController < ::BudgetControl::ApplicationController
    before_action :set_contractor, only: %i[edit update destroy]

    def index
      @contractors = scoped_relation(BcContractor).order(:name)
    end

    def new
      @contractor = @project.bc_contractors.build
    end

    def create
      @contractor = @project.bc_contractors.build(contractor_params)
      if @contractor.save
        flash[:notice] = 'Contratista creado correctamente.'
        redirect_to bc_contractors_path(project_id: @project)
      else
        render :new
      end
    end

    def edit
      # @contractor es cargado por el before_action
    end

    def update
      if @contractor.update(contractor_params)
        flash[:notice] = 'Contratista actualizado correctamente.'
        redirect_to bc_contractors_path(project_id: @project)
      else
        render :edit
      end
    end

    def destroy
      if @contractor.destroy
        flash[:notice] = 'Contratista eliminado correctamente.'
      else
        # Muestra un error si no se puede eliminar (ej. por tener contratos asociados)
        flash[:error] = @contractor.errors.full_messages.to_sentence
      end
      redirect_to bc_contractors_path(project_id: @project)
    end

    def export
      @contractors = scoped_relation(BcContractor).order(:name)
      respond_to do |format|
        format.xlsx {
          response.headers['Content-Disposition'] = "attachment; filename=\"contratistas_#{@project.identifier}_#{Time.now.strftime('%Y%m%d')}.xlsx\""
        }
      end
    end
    
    def import
      file = params[:file]
      unless file && file.content_type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        flash[:error] = 'Por favor, sube un archivo XLSX válido.'
        redirect_to bc_contractors_path(project_id: @project) and return
      end
    
      imported_count = 0
      updated_count = 0
      failed_rows = []
    
      begin
        spreadsheet = Roo::Excelx.new(file.path)
        header = spreadsheet.row(1).map { |h| h.to_s.strip } # Obtener encabezados y asegurar que sean strings
    
        # Encabezados esperados (insensibles a mayúsculas/minúsculas)
        required_headers = ['Nombre', 'Responsable']
        # Verificar que al menos los encabezados obligatorios estén presentes
        unless required_headers.all? { |h| header.map(&:downcase).include?(h.downcase) }
          flash[:error] = "El archivo Excel no contiene las columnas obligatorias. Se requieren al menos: #{required_headers.join(', ')}."
          redirect_to bc_contractors_path(project_id: @project) and return
        end
    
        # Mapear nombres de encabezado a nombres de atributos del modelo para mayor claridad
        header_map = {
          'nombre'      => :name,
          'responsable' => :manager,
          'telefono'    => :phone,
          'email'       => :email
        }
    
        (2..spreadsheet.last_row).each do |i|
          row = Hash[header.zip(spreadsheet.row(i).map(&:to_s))]
          # Convertir claves a minúsculas para coincidir con header_map
          row_data_normalized = row.transform_keys { |k| k.to_s.downcase }
    
          # Extraer atributos, manejando posibles valores nulos del Excel
          contractor_attrs = {}
          header_map.each do |excel_col, model_attr|
            contractor_attrs[model_attr] = row_data_normalized[excel_col].to_s.strip if row_data_normalized[excel_col].present?
          end
    
          # Saltar fila si el nombre está vacío, ya que es requerido para find_or_initialize_by y validación
          unless contractor_attrs[:name].present?
            failed_rows << "Fila #{i}: El nombre del contratista no puede estar vacío."
            next
          end
    
          # Busca un contratista por nombre dentro del proyecto o inicializa uno nuevo.
          # Esto evita duplicados si el contratista ya existe.
          contractor = @project.bc_contractors.find_or_initialize_by(name: contractor_attrs[:name])
          is_new_record = contractor.new_record?
    
          # Asigna los demás atributos leídos desde el Excel.
          # Si el registro ya existía, esto actualizará sus datos.
          contractor.assign_attributes(contractor_attrs)
    
          if contractor.save
            if is_new_record
              imported_count += 1
            else
              # Solo cuenta como actualizado si hubo cambios reales en los atributos.
              updated_count += 1 if contractor.previous_changes.any?
            end
          else
            # Si falla el guardado, se registra el error.
            failed_rows << "Fila #{i}: #{contractor.errors.full_messages.to_sentence} (Datos: #{contractor_attrs.values.join(', ')})"
          end
        end
    
        success_message = []
        success_message << "#{imported_count} contratistas creados." if imported_count > 0
        success_message << "#{updated_count} contratistas actualizados." if updated_count > 0
        flash[:notice] = success_message.join(' ') if success_message.any?
    
        if failed_rows.any?
          # Para evitar CookieOverflow, no guardamos todos los errores en el flash.
          # Mostramos un resumen y registramos los detalles en el log del servidor.
          error_summary = "Se encontraron errores en la importación de #{failed_rows.count} filas."
          if failed_rows.count <= 5
            flash[:error] = "#{error_summary} Detalles: #{failed_rows.join('; ')}"
          else
            flash[:error] = "#{error_summary} Por favor, revise los logs del servidor para ver los detalles completos."
          end
          Rails.logger.error "Errores de importación de contratistas: \n#{failed_rows.join("\n")}"
        end
    
      rescue Roo::HeaderRowNotFoundError
        flash[:error] = "Error en el archivo Excel: No se encontró la fila de encabezado. Asegúrate de que la primera fila contenga los nombres de las columnas esperadas (Nombre, Responsable, Teléfono, Email)."
      rescue => e
        flash[:error] = "Error inesperado al importar el archivo: #{e.message}"
        Rails.logger.error "Import error in Bc::ContractorsController: #{e.message}\n#{e.backtrace.join("\n")}"
      end
      # Asegurarse de redirigir siempre al final de la acción
      redirect_to bc_contractors_path(project_id: @project)
    end

    private

    def contractor_params
      params.require(:bc_contractor).permit(:name, :manager, :phone, :email)
    end

    def set_contractor
      @contractor = scoped_relation(BcContractor).find(params[:id])
    end
  end
end