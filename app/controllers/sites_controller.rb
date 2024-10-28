class SitesController < ApplicationController
  unloadable

  before_action :require_login
  before_action :require_admin, except: [:search, :index, :show]
  before_action :find_site, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :load_site_collections, only: [:new, :create, :edit, :update]
  before_action :build_site_query, only: [:index]
  skip_before_action :verify_authenticity_token, only: [:search]

  helper :sort
  include SortHelper

  def index
    sort_init 's_id', 'asc'
    sort_update %w[s_id nom_sitio depto municipio jerarquia_definitiva fijo_variable]

    @limit = per_page_option
    scope = build_index_scope

    @site_count = scope.count
    @site_pages = Paginator.new @site_count, @limit, params['page']
    @offset ||= @site_pages.offset
    @sites = scope.limit(@limit).offset(@offset)

    respond_to do |format|
      format.html
      format.json { render json: { sites: @sites, total: @site_count } }
      format.api
      format.csv { 
        send_data export_to_csv(@sites), 
        filename: "sites-#{Date.today}.csv",
        type: 'text/csv; charset=utf-8'
      }
      format.xlsx { 
        send_data export_to_xlsx(@sites), 
        filename: "sites-#{Date.today}.xlsx",
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      }
    end
  rescue StandardError => e
    flash[:error] = e.message
    redirect_to sites_path
  end

  def show
    respond_to do |format|
      format.html
      format.api
      format.json { render json: @site.to_json_for_details }
    end
  end

  def new
    @site = FlmSite.new
  end

  def create
    @site = FlmSite.new(site_params)

    respond_to do |format|
      if @site.save
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_to sites_path
        end
        format.json { render json: @site.to_json_for_details, status: :created }
      else
        load_site_collections
        format.html { render :new }
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @site.update(site_params)
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to sites_path
        end
        format.json { render json: @site.to_json_for_details }
      else
        load_site_collections
        format.html { render :edit }
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @site.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l('plugin_sites_manager.messages.delete_error')
    end

    respond_to do |format|
      format.html { redirect_to sites_path }
      format.json { head :no_content }
    end
  end

  def download_template
    require 'csv'
  
    begin
      csv_data = CSV.generate(col_sep: ';', encoding: 'utf-8') do |csv|
        # Encabezados
        csv << [
          'S ID (*)',
          'Departamento',
          'Municipio',
          'Nombre Sitio (*)',
          'Dirección',
          'Identificador',
          'Jerarquía Definitiva',
          'Fijo/Variable',
          'Coordinador',
          'Electrificadora',
          'NIC',
          'Campo Adicional 3',
          'Campo Adicional 4',
          'Campo Adicional 5'
        ]
  
        # Datos de ejemplo
        csv << [
          'S001',
          'ANTIOQUIA',
          'MEDELLÍN',
          'SITIO EJEMPLO',
          'CALLE 123',
          'ID001',
          'B_1',
          'FIJO',
          'JUAN PEREZ',
          'EPM',
          '12345',
          'VALOR 3',
          'VALOR 4',
          'VALOR 5'
        ]
      end
  
      bom = "\xEF\xBB\xBF"
      send_data bom + csv_data.force_encoding('UTF-8'),
                filename: "plantilla_sitios_#{Date.today.strftime('%Y%m%d')}.csv",
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue StandardError => e
      Rails.logger.error "Error generando plantilla: #{e.message}"
      flash[:error] = l('plugin_sites_manager.messages.template_generation_error')
      redirect_to import_sites_path
    end
  end

  def search
    # No requerir login para la búsqueda
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless User.current.logged?

    term = params[:term].to_s.strip.downcase
    @sites = search_sites(term)

    respond_to do |format|
      format.json { render json: format_sites_for_json(@sites) }
    end
  rescue StandardError => e
    Rails.logger.error "Error en búsqueda de sitios: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  def import
    if request.post?
      if params[:file].present?
        begin
          result = import_sites_from_file
          set_import_flash_message(result)
          redirect_to sites_path
        rescue StandardError => e
          flash.now[:error] = "#{l('plugin_sites_manager.messages.import_error')}: #{e.message}"
          render :import
        end
      else
        flash.now[:error] = l('plugin_sites_manager.messages.no_file')
        render :import
      end
    end
  end
  
  private

  def toggle_status
    respond_to do |format|
      if @site.toggle_status!
        format.html do
          flash[:notice] = l('plugin_sites_manager.messages.status_updated')
          redirect_to sites_path
        end
        format.json { render json: { status: @site.active, success: true } }
      else
        format.html do
          flash[:error] = l('plugin_sites_manager.messages.status_update_failed')
          redirect_to sites_path
        end
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def bulk_update
    if params[:ids].blank? || params[:action_name].blank?
      flash[:error] = l('plugin_sites_manager.messages.no_selection')
      return redirect_to sites_path
    end

    perform_bulk_update
    redirect_to sites_path
  rescue StandardError => e
    flash[:error] = e.message
    redirect_to sites_path
  end

  private

  def find_site
    @site = FlmSite.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def load_site_collections
    @departamentos = FlmSite.distinct.pluck(:depto).compact.sort
    @municipios = FlmSite.distinct.pluck(:municipio).compact.sort
    @jerarquias = FlmSite.distinct.pluck(:jerarquia_definitiva).compact.sort
  end

  def site_params
    params.require(:flm_site).permit(
      :s_id, :depto, :municipio, :nom_sitio, :direccion, :identificador,
      :jerarquia_definitiva, :fijo_variable, :coordinador,
      :electrificadora, :nic, :campo_adicional_3,
      :campo_adicional_4, :campo_adicional_5
    )
  end
  

  def search_sites(term)
    FlmSite.where(
      "LOWER(s_id) LIKE :term OR 
       LOWER(nom_sitio) LIKE :term OR 
       LOWER(identificador) LIKE :term OR 
       LOWER(municipio) LIKE :term OR 
       LOWER(direccion) LIKE :term OR 
       LOWER(NIC) LIKE :term OR 
       LOWER(depto) LIKE :term", 
      term: "%#{term}%"
    ).limit(10)
  end

  def format_sites_for_json(sites)
    sites.map { |site| 
      {
        id: site.id,
        label: "#{site.s_id} - #{site.nom_sitio}",
        value: site.nom_sitio,
        site_data: {
          s_id: site.s_id,
          nom_sitio: site.nom_sitio,
          identificador: site.identificador,
          depto: site.depto,
          municipio: site.municipio,
          direccion: site.direccion,
          jerarquia_definitiva: site.jerarquia_definitiva,
          fijo_variable: site.fijo_variable,
          coordinador: site.coordinador,
          electrificadora: site.electrificadora,
          nic: site.nic
        }
      }
    }
  end

  def build_site_query
    @query = params[:search].present? ? { search: params[:search] } : {}
  end

  def build_index_scope
    scope = FlmSite.order(sort_clause.presence || 'created_at DESC')

    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      scope = scope.where("LOWER(s_id) LIKE ? OR LOWER(nom_sitio) LIKE ?", search_term, search_term)
    end

    scope
  end

  def build_search_scope
    scope = FlmSite.active

    if params[:term].present?
      term = "%#{params[:term].strip.downcase}%"
      scope = scope.where(
        "LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term OR LOWER(identificador) LIKE :term",
        term: term
      )
    end

    scope = scope.by_depto(params[:depto]) if params[:depto].present?
    scope = scope.by_municipio(params[:municipio]) if params[:municipio].present?

    scope
  end

  def import_sites_from_file
    raise l('plugin_sites_manager.messages.no_file') unless params[:file].present?
    raise l('plugin_sites_manager.messages.invalid_file_type') unless valid_import_file?(params[:file])
  
    process_import_file(params[:file])
  end
  

  def process_import_file(file)
    require 'csv'
    
    result = { imported: 0, updated: 0, failed: 0, errors: [] }
    
    begin
      content = File.read(file.path).force_encoding('UTF-8')
      content = content.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: '')
      content = content.gsub("\xEF\xBB\xBF", '') # Eliminar BOM si existe
      
      Rails.logger.info "Iniciando importación de archivo CSV"
      Rails.logger.debug "Contenido del archivo:\n#{content}"
      
      csv = CSV.parse(content, headers: true, col_sep: detect_separator(content))
      
      csv.each.with_index(1) do |row, index|
        Rails.logger.debug "Procesando fila #{index}: #{row.to_hash}"
        process_row(row, result)
      end
  
      Rails.logger.info "Importación completada: #{result[:imported]} importados, #{result[:updated]} actualizados, #{result[:failed]} fallidos"
    rescue StandardError => e
      Rails.logger.error "Error en importación: #{e.message}\n#{e.backtrace.join("\n")}"
      result[:errors] << "Error general: #{e.message}"
    end
    
    result
  end
  
  def detect_file_encoding(file_path)
    first_bytes = File.read(file_path, 4)
    return 'bom|utf-8' if first_bytes.start_with?("\xEF\xBB\xBF")
    'utf-8'
  end
  
  def detect_separator(file_path)
    first_line = File.open(file_path, &:readline)
    return ';' if first_line.include?(';')
    ','
  end
  
  def detect_separator(content)
    first_line = content.lines.first.to_s
    return ';' if first_line.include?(';')
    ','
  end

  def process_row(row, result)
    return if row.to_hash.values.all?(&:nil?) # Saltar filas vacías
    
    attributes = row.to_hash.transform_keys { |k| k.to_s.downcase.strip.gsub(/[(*)]/, '').strip }
    current_row = result[:imported] + result[:updated] + result[:failed] + 1
    
    # Mapeo de campos
    site_attrs = {
      s_id: normalize_s_id(find_value(attributes, ['s id', 's_id', 'sid'])),
      depto: find_value(attributes, ['departamento', 'depto']),
      municipio: find_value(attributes, ['municipio']),
      nom_sitio: find_value(attributes, ['nombre sitio', 'nom_sitio', 'nombre_sitio']),
      direccion: find_value(attributes, ['direccion', 'dirección']),
      identificador: find_value(attributes, ['identificador']),
      jerarquia_definitiva: find_value(attributes, ['jerarquia definitiva', 'jerarquía definitiva']),
      fijo_variable: find_value(attributes, ['fijo/variable', 'fijo_variable']),
      coordinador: find_value(attributes, ['coordinador']),
      electrificadora: find_value(attributes, ['electrificadora']),
      nic: find_value(attributes, ['nic']),
      campo_adicional_3: find_value(attributes, ['campo adicional 3', 'campo_adicional_3']),
      campo_adicional_4: find_value(attributes, ['campo adicional 4', 'campo_adicional_4']),
      campo_adicional_5: find_value(attributes, ['campo adicional 5', 'campo_adicional_5'])
    }
  
    # Validaciones previas
    validations = []
    validations << "S ID" if site_attrs[:s_id].blank?
    validations << "Nombre Sitio" if site_attrs[:nom_sitio].blank?
    
    if validations.any?
      result[:failed] += 1
      result[:errors] << "Fila #{current_row}: Campos requeridos faltantes: #{validations.join(', ')}"
      return
    end
  
    # Validar formato de S ID
    unless site_attrs[:s_id] =~ /\AS\d+\z/
      result[:failed] += 1
      result[:errors] << "Fila #{current_row}: Formato de S ID inválido (debe ser 'S' seguido de números)"
      return
    end
  
    begin
      site = FlmSite.find_or_initialize_by(s_id: site_attrs[:s_id])
      
      if site.new_record?
        if site.update(site_attrs)
          result[:imported] += 1
        else
          result[:failed] += 1
          result[:errors] << "Fila #{current_row}: #{site.errors.full_messages.join(', ')}"
        end
      else
        if site.update(site_attrs)
          result[:updated] += 1
        else
          result[:failed] += 1
          result[:errors] << "Fila #{current_row}: #{site.errors.full_messages.join(', ')}"
        end
      end
    rescue StandardError => e
      result[:failed] += 1
      result[:errors] << "Fila #{current_row}: Error - #{e.message}"
    end
  end
  
  private
  
  def export
    begin
      @sites = FlmSite.all # o build_export_scope si tienes ese método

      require 'csv'
      
      # Generar CSV con BOM para Excel
      csv_data = CSV.generate(col_sep: ';', encoding: 'utf-8') do |csv|
        # Encabezados
        csv << [
          'S ID',
          'Departamento',
          'Municipio',
          'Nombre Sitio',
          'Dirección',
          'Identificador',
          'Jerarquía Definitiva',
          'Fijo/Variable',
          'Coordinador',
          'Electrificadora',
          'NIC',
          'Campo Adicional 3',
          'Campo Adicional 4',
          'Campo Adicional 5'
        ]

        # Datos
        @sites.each do |site|
          csv << [
            site.s_id,
            site.depto,
            site.municipio,
            site.nom_sitio,
            site.direccion,
            site.identificador,
            site.jerarquia_definitiva,
            site.fijo_variable,
            site.coordinador,
            site.electrificadora,
            site.nic,
            site.campo_adicional_3,
            site.campo_adicional_4,
            site.campo_adicional_5
          ]
        end
      end

      # Agregar BOM para Excel
      bom = "\xEF\xBB\xBF"
      send_data bom + csv_data,
                filename: "sitios_#{Date.today.strftime('%Y%m%d')}.csv",
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue StandardError => e
      Rails.logger.error "Error exportando sitios: #{e.message}\n#{e.backtrace.join("\n")}"
      flash[:error] = l('plugin_sites_manager.messages.export_error')
      redirect_to sites_path
    end
  end

  private
  
  def build_export_scope
    scope = FlmSite.all
    
    if params[:search].present?
      term = "%#{params[:search].downcase}%"
      scope = scope.where(
        "LOWER(s_id) LIKE :term OR 
         LOWER(nom_sitio) LIKE :term OR 
         LOWER(municipio) LIKE :term OR 
         LOWER(depto) LIKE :term",
        term: term
      )
    end
    
    scope
  end
  
  def generate_csv(sites)
    require 'csv'
  
    # Agregar BOM para Excel
    bom = "\xEF\xBB\xBF"
    
    csv_data = CSV.generate(col_sep: ';') do |csv|
      # Encabezados
      csv << [
        'S ID',
        'Departamento',
        'Municipio',
        'Nombre Sitio',
        'Dirección',
        'Identificador',
        'Jerarquía Definitiva',
        'Fijo/Variable',
        'Coordinador',
        'Electrificadora',
        'NIC',
        'Campo Adicional 3',
        'Campo Adicional 4',
        'Campo Adicional 5'
      ]
  
      # Datos
      sites.find_each do |site|
        csv << [
          site.s_id,
          site.depto,
          site.municipio,
          site.nom_sitio,
          site.direccion,
          site.identificador,
          site.jerarquia_definitiva,
          site.fijo_variable,
          site.coordinador,
          site.electrificadora,
          site.nic,
          site.campo_adicional_3,
          site.campo_adicional_4,
          site.campo_adicional_5
        ]
      end
    end
  
    bom + csv_data
  end

  def normalize_s_id(value)
    return nil if value.blank?
    
    normalized = value.to_s.strip.upcase
    if normalized =~ /^\d+$/
      "S#{normalized}"
    elsif normalized !~ /^S/ && normalized =~ /\d+/
      "S#{normalized.gsub(/[^0-9]/, '')}"
    else
      normalized
    end
  end

  def find_value(attributes, possible_keys)
    possible_keys.each do |key|
      value = attributes[key]
      return value if value.present?
    end
    nil
  end

  def import_from_csv(file)
    require 'csv'
    
    result = { imported: 0, updated: 0, failed: 0, errors: [] }
    
    begin
      CSV.foreach(file.path, headers: true, col_sep: ';', encoding: 'bom|utf-8') do |row|
        # Convertir la fila a un hash con las claves normalizadas
        attributes = row.to_hash.transform_keys(&:downcase)
        
        # Buscar o crear el sitio
        site = FlmSite.find_or_initialize_by(s_id: attributes['s id'])
        
        # Mapear los campos
        site_attributes = {
          s_id: attributes['s id'],
          depto: attributes['departamento'],
          municipio: attributes['municipio'],
          nom_sitio: attributes['nombre sitio'],
          direccion: attributes['dirección'],
          identificador: attributes['identificador'],
          jerarquia_definitiva: attributes['jerarquía definitiva'],
          fijo_variable: attributes['fijo/variable'],
          coordinador: attributes['coordinador'],
          electrificadora: attributes['electrificadora'],
          nic: attributes['nic'],
          campo_adicional_3: attributes['campo adicional 3'],
          campo_adicional_4: attributes['campo adicional 4'],
          campo_adicional_5: attributes['campo adicional 5']
        }
  
        if site.new_record?
          result[:imported] += 1 if site.update(site_attributes)
        else
          result[:updated] += 1 if site.update(site_attributes)
        end
      rescue StandardError => e
        result[:failed] += 1
        result[:errors] << "Fila #{$.}: #{e.message}"
      end
    end
    
    result
  end

  def valid_import_file?(file)
    extension = File.extname(file.original_filename).downcase
    valid_extensions = ['.csv']
    
    unless valid_extensions.include?(extension)
      Rails.logger.error "Extensión de archivo inválida: #{extension}"
      return false
    end
    
    true
  end

  def set_import_flash_message(result)
    result[:imported] ||= 0
    result[:updated] ||= 0
    result[:failed] ||= 0
    
    if result[:errors].any?
      message = l('plugin_sites_manager.messages.import_partial',
                  imported: result[:imported],
                  updated: result[:updated],
                  failed: result[:failed])
      
      # Organizar errores por tipo
      error_messages = result[:errors].group_by { |error| error[/^.*?:/] || 'Otros:' }
      formatted_errors = error_messages.map do |type, errors|
        "<strong>#{type}</strong><ul>" +
        errors.map { |e| "<li>#{e.sub(type, '')}</li>" }.join + 
        "</ul>"
      end.join
  
      flash[:error] = message
      flash[:warning] = formatted_errors.html_safe
    else
      flash[:notice] = l('plugin_sites_manager.messages.import_success',
                        imported: result[:imported],
                        updated: result[:updated])
    end
  end

  def perform_bulk_update
    case params[:action_name]
    when 'activate'
      FlmSite.where(id: params[:ids]).update_all(active: true)
      flash[:notice] = l('plugin_sites_manager.messages.bulk_activate_success')
    when 'deactivate'
      FlmSite.where(id: params[:ids]).update_all(active: false)
      flash[:notice] = l('plugin_sites_manager.messages.bulk_deactivate_success')
    when 'delete'
      FlmSite.where(id: params[:ids]).destroy_all
      flash[:notice] = l('plugin_sites_manager.messages.bulk_delete_success')
    else
      flash[:error] = l('plugin_sites_manager.messages.invalid_action')
    end
  end
end