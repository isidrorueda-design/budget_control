# plugins/budget_control/app/controllers/bc/estimates_controller.rb
class Bc::EstimatesController < ::BudgetControl::ApplicationController
  # :find_project ya viene del padre
  before_action :set_selects, only: %i[new create edit update]
  before_action :set_estimate, only: %i[edit update destroy]
  def index
    scope = scoped_relation(BcEstimate)
    scope = scope.joins(:contract).where(bc_contracts: { contractor_id: params[:contractor_id] }) if params[:contractor_id].present? # joins es correcto para filtrar
    scope = scope.where(contract_id: params[:contract_id]) if params[:contract_id].present?

    @estimates = scope.includes(:contract, :contractor).order('bc_contracts.number, bc_estimates.estimate_num')

    # Calcula los totales para la fila de resumen
    @totals = {
      estimated: @estimates.sum(&:estimated),
      amortized: @estimates.sum(&:amortized),
      warranty_fund: @estimates.sum(&:warranty_fund),
      retentions: @estimates.sum(&:retentions),
      deductive: @estimates.sum(&:deductive)
    }
    # Carga los contratistas que tienen estimaciones en este proyecto.
    # La consulta es más explícita para evitar errores de inferencia de Rails.
    contractor_ids_with_estimates = scoped_relation(BcEstimate).select(:contractor_id).distinct
    @contractor_for_select = scoped_relation(BcContractor).where(id: contractor_ids_with_estimates).order(:name)

    @contracts_for_select    = params[:contractor_id].present? ? scoped_relation(BcContract).where(contractor_id: params[:contractor_id]).order(:number) : BcContract.none
  end

  def new
    @estimate = @project.bc_estimates.build   # ← build sobre la asociación
    # set_selects se encarga de las colecciones
  end

  def create
    @estimate = @project.bc_estimates.build(permitted_params)
    # valores por defecto
    @estimate.amortized     ||= 0
    @estimate.warranty_fund ||= 0
    @estimate.retentions    ||= 0
    @estimate.deductive     ||= 0

    if @estimate.save
      redirect_to bc_estimates_path(project_id: @project), notice: 'Estimación guardada.'
    else
      # set_selects ya fue llamado por el before_action
      render :new
    end
  end

  def edit
    # @estimate ya está cargado por el before_action :set_estimate
  end

  def update
    # Aseguramos que los campos numéricos vacíos se traten como 0
    @estimate.assign_attributes(permitted_params)
    @estimate.amortized     ||= 0
    @estimate.warranty_fund ||= 0
    @estimate.retentions    ||= 0
    @estimate.deductive     ||= 0
    if @estimate.save
      redirect_to bc_estimates_path(project_id: @project), notice: 'Estimación actualizada correctamente.'
    else
      render :edit
    end
  end

  # AJAX para cargar contratos según contratista
  def contracts
    Rails.logger.info "Bc::EstimatesController#contracts AJAX called - project_id=#{@project&.id} contractor_id=#{params[:contractor_id]}"
    list = scoped_relation(BcContract).where(contractor_id: params[:contractor_id])
    Rails.logger.info "Bc::EstimatesController#contracts - found #{list.count} contracts for contractor_id=#{params[:contractor_id]} in project #{@project&.id}"
    render json: list.as_json(only: [:id, :number])
  end

  def destroy
    if @estimate.destroy
      flash[:notice] = 'Estimación eliminada correctamente.'
    else
      flash[:error] = @estimate.errors.full_messages.to_sentence
    end
    redirect_to bc_estimates_path(project_id: @project)
  end

  def export
    @estimates = scoped_relation(BcEstimate).includes(contract: :contractor).order('bc_contracts.number, bc_estimates.estimate_num')
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"estimaciones_#{@project.identifier}_#{Time.now.strftime('%Y%m%d')}.xlsx\""
      }
    end
  end

  def import
    file = params[:file]
    unless file && file.content_type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      flash[:error] = 'Por favor, sube un archivo XLSX válido.'
      redirect_to bc_estimates_path(project_id: @project) and return
    end

    imported_count = 0
    updated_count = 0
    failed_rows = []

    begin
      spreadsheet = Roo::Excelx.new(file.path)
      header = spreadsheet.row(1).map { |h| h.to_s.strip.downcase }

      required_headers = ['contrato', 'estimacion', 'monto estimado']
      unless required_headers.all? { |h| header.include?(h) }
        flash[:error] = "El archivo Excel no contiene las columnas obligatorias. Se requieren: #{required_headers.join(', ')}."
        redirect_to bc_estimates_path(project_id: @project) and return
      end

      (2..spreadsheet.last_row).each do |i|
        row = Hash[header.zip(spreadsheet.row(i).map(&:to_s))]

        contract_number = row['contrato'].to_s.strip
        estimate_number = row['estimacion'].to_s.strip

        unless contract_number.present? && estimate_number.present?
          failed_rows << "Fila #{i}: El número de contrato y de estimación son obligatorios."
          next
        end

        contract = @project.bc_contracts.find_by(number: contract_number)
        unless contract
          failed_rows << "Fila #{i}: No se encontró el contrato con número '#{contract_number}' en este proyecto."
          next
        end

        estimate = @project.bc_estimates.find_or_initialize_by(contract_id: contract.id, estimate_num: estimate_number)
        is_new_record = estimate.new_record?

        clean_currency = ->(value) { value.to_s.gsub(/[$,]/, '').tr('.', ',').sub(',', '.').to_f }

        estimate.assign_attributes(
          contractor_id: contract.contractor_id,
          estimate_date: (Date.parse(row['fecha']) rescue Date.today),
          estimated:     clean_currency.call(row['monto estimado']),
          amortized:     clean_currency.call(row['amortizado']),
          warranty_fund: clean_currency.call(row['fondo de garantia']),
          retentions:    clean_currency.call(row['retenciones']),
          deductive:     clean_currency.call(row['deductivas'])
        )

        if estimate.save
          is_new_record ? imported_count += 1 : updated_count += 1
        else
          failed_rows << "Fila #{i} (Contrato #{contract_number}, Est #{estimate_number}): #{estimate.errors.full_messages.to_sentence}"
        end
      end

      flash[:notice] = "#{imported_count} estimaciones creadas y #{updated_count} actualizadas." if imported_count > 0 || updated_count > 0
      if failed_rows.any?
        error_summary = "Se encontraron errores en #{failed_rows.count} filas."
        flash[:error] = "#{error_summary} Detalles: #{failed_rows.take(3).join('; ')}"
        Rails.logger.error "Errores de importación de estimaciones: \n#{failed_rows.join("\n")}"
      end

    rescue => e
      flash[:error] = "Error inesperado al importar: #{e.message}"
      Rails.logger.error "Import error in Bc::EstimatesController: #{e.message}\n#{e.backtrace.join("\n")}"
    end
    redirect_to bc_estimates_path(project_id: @project)
  end

  private

  def permitted_params
    params.require(:bc_estimate).permit(:contractor_id, :contract_id, :estimate_num,
                                        :estimate_date, :estimated, :amortized,
                                        :warranty_fund, :retentions, :deductive)
  end

  # llena listas desplegables en new / create (error o éxito)
  def set_selects
    # Para la lista de contratistas
    @contractor_for_select = scoped_relation(BcContractor).order(:name)

    # Para la lista de contratos, se carga vacía inicialmente.
    # Si el formulario se recarga por un error, se intenta pre-cargar
    # la lista basada en el contratista que ya había sido seleccionado.
    contractor_id = params.dig(:bc_estimate, :contractor_id) || @estimate&.contractor_id
    @contracts_for_select = contractor_id.present? ? scoped_relation(BcContract).where(contractor_id: contractor_id) : BcContract.none
  end

  def set_estimate
    @estimate = scoped_relation(BcEstimate).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'Estimación no encontrada.'
    redirect_to bc_estimates_path(project_id: @project)
  end
end