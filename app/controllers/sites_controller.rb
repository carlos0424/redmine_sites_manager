class SitesController < ApplicationController
  unloadable

  before_action :require_login
  before_action :require_admin, except: [:search, :autocomplete]
  before_action :find_site, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :load_site_collections, only: [:new, :create, :edit, :update]
  before_action :build_site_query, only: [:index]
  skip_before_action :verify_authenticity_token, only: [:search]
  before_action :verify_sites_manager_access, except: [:search, :autocomplete]

  helper :sort
  include SortHelper

  EXPORTABLE_HEADERS = [
    'S ID', 'Departamento', 'Municipio', 'Nombre Sitio', 'Dirección',
    'Identificador', 'Jerarquía Definitiva', 'Fijo/Variable', 'Coordinador',
    'Electrificadora', 'NIC', 'zona_operativa', 'Campo Adicional 4',
    'Campo Adicional 5'
  ].freeze

  EXAMPLE_DATA = [
    'S001', 'ANTIOQUIA', 'MEDELLÍN', 'SITIO EJEMPLO', 'CALLE 123',
    'ID001', 'B_1', 'FIJO', 'JUAN PEREZ', 'EPM', '12345', 'VALOR 3',
    'VALOR 4', 'VALOR 5'
  ].freeze

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
      format.csv { export_csv }
      format.xlsx { export_xlsx }
    end
  rescue StandardError => e
    handle_error(e)
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
    save_and_respond(:create)
  end

  def edit
  end

  def update
    @site.attributes = site_params
    save_and_respond(:update)
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
    csv_data = generate_csv_template
    send_file_response(csv_data, "plantilla_sitios_#{Date.today.strftime('%Y%m%d')}.csv")
  rescue StandardError => e
    handle_template_error(e)
  end

  def search
    return unauthorized_error unless User.current.logged?

    begin
      @sites = search_sites(params[:term])
      render json: format_sites_for_json(@sites)
    rescue StandardError => e
      log_error("Error en búsqueda de sitios", e)
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  def autocomplete
    return unauthorized_error unless User.current.logged?
    @sites = search_sites(params[:term])
    render json: format_sites_for_json(@sites)
  end

  def import
    return unless request.post?
    return missing_file_error unless params[:file].present?

    begin
      result = process_import_file(params[:file])
      set_import_flash_message(result)
      redirect_to sites_path
    rescue StandardError => e
      flash.now[:error] = "#{l('plugin_sites_manager.messages.import_error')}: #{e.message}"
      render :import
    end
  end

  def export
    @sites = build_export_scope
    send_file_response(
      generate_csv(@sites),
      "sitios_#{Date.today.strftime('%Y%m%d')}.csv"
    )
  rescue StandardError => e
    handle_export_error(e)
  end

  private

  def save_and_respond(action)
    respond_to do |format|
      if @site.save
        format.html do
          flash[:notice] = l("notice_successful_#{action}")
          redirect_to sites_path
        end
        format.json { render json: @site.to_json_for_details, status: (action == :create ? :created : :ok) }
      else
        load_site_collections
        format.html { render action }
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def process_import_file(file)
    raise l('plugin_sites_manager.messages.invalid_file_type') unless valid_import_file?(file)
    
    result = { imported: 0, updated: 0, failed: 0, errors: [] }
    process_csv_content(file, result)
    result
  rescue StandardError => e
    log_error("Error en importación", e)
    result[:errors] << "Error general: #{e.message}"
    result
  end

  def process_csv_content(file, result)
    content = read_csv_file(file)
    csv = CSV.parse(content, headers: true, col_sep: detect_separator(content))
    
    csv.each.with_index(1) do |row, index|
      process_csv_row(row, result, index)
    end
  end

  def read_csv_file(file)
    content = File.read(file.path).force_encoding('UTF-8')
    content = content.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: '')
    content.gsub("\xEF\xBB\xBF", '')
  end

  def process_csv_row(row, result, row_index)
    return if row.to_hash.values.all?(&:nil?)
    
    site_attrs = build_site_attributes(row.to_hash)
    validate_and_save_site(site_attrs, result, row_index)
  rescue StandardError => e
    handle_row_error(e, result, row_index)
  end

  def build_site_attributes(row_hash)
    attributes = normalize_row_keys(row_hash)
    {
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
      zona_operativa: find_value(attributes, ['zona_operativa']),
      campo_adicional_4: find_value(attributes, ['campo adicional 4', 'campo_adicional_4']),
      campo_adicional_5: find_value(attributes, ['campo adicional 5', 'campo_adicional_5'])
    }
  end

  def validate_and_save_site(attrs, result, row_index)
    validate_required_fields!(attrs, result, row_index)
    validate_s_id_format!(attrs[:s_id], result, row_index)
    
    site = FlmSite.find_or_initialize_by(s_id: attrs[:s_id])
    save_site(site, attrs, result)
  end

  def save_site(site, attrs, result)
    if site.new_record?
      result[:imported] += 1 if site.update(attrs)
    else
      result[:updated] += 1 if site.update(attrs)
    end
  rescue StandardError => e
    result[:failed] += 1
    result[:errors] << e.message
  end

  def search_sites(term)
    term = term.to_s.strip.downcase
    FlmSite.where(search_conditions, term: "%#{term}%").limit(10)
  end

  def search_conditions
    "LOWER(s_id) LIKE :term OR 
     LOWER(nom_sitio) LIKE :term OR 
     LOWER(identificador) LIKE :term OR 
     LOWER(municipio) LIKE :term OR 
     LOWER(direccion) LIKE :term OR 
     LOWER(depto) LIKE :term"
  end

  def format_sites_for_json(sites)
    sites.map do |site|
      {
        id: site.id,
        label: "#{site.s_id} - #{site.nom_sitio}",
        value: site.nom_sitio,
        site_data: site_data_for_json(site)
      }
    end
  end

  def site_data_for_json(site)
    {
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
      nic: site.nic,
      zona_operativa: site.zona_operativa
    }
  end

  def build_index_scope
    scope = FlmSite.order(sort_clause.presence || 'created_at DESC')
    return scope unless params[:search].present?

    search_term = "%#{params[:search].downcase}%"
    scope.where("LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term", term: search_term)
  end

  def build_export_scope
    scope = FlmSite.all
    return scope unless params[:search].present?

    term = "%#{params[:search].downcase}%"
    scope.where(
      "LOWER(s_id) LIKE :term OR 
       LOWER(nom_sitio) LIKE :term OR 
       LOWER(municipio) LIKE :term OR 
       LOWER(depto) LIKE :term",
      term: term
    )
  end

  def generate_csv_template
    CSV.generate(col_sep: ';', encoding: 'utf-8') do |csv|
      csv << EXPORTABLE_HEADERS
      csv << EXAMPLE_DATA
    end
  end

  def generate_csv(sites)
    CSV.generate(col_sep: ';') do |csv|
      csv << EXPORTABLE_HEADERS
      sites.find_each { |site| csv << site_to_row(site) }
    end
  end

  def site_to_row(site)
    [
      site.s_id, site.depto, site.municipio, site.nom_sitio,
      site.direccion, site.identificador, site.jerarquia_definitiva,
      site.fijo_variable, site.coordinador, site.electrificadora,
      site.nic, site.zona_operativa, site.campo_adicional_4,
      site.campo_adicional_5
    ]
  end

  def send_file_response(data, filename)
    send_data "\xEF\xBB\xBF" + data.force_encoding('UTF-8'),
              filename: filename,
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end

  def validate_required_fields!(attrs, result, row_index)
    missing_fields = []
    missing_fields << "S ID" if attrs[:s_id].blank?
    missing_fields << "Nombre Sitio" if attrs[:nom_sitio].blank?
    
    if missing_fields.any?
      result[:failed] += 1
      result[:errors] << "Fila #{row_index}: Campos requeridos faltantes: #{missing_fields.join(', ')}"
      raise "Campos requeridos faltantes"
    end
  end

  def validate_s_id_format!(s_id, result, row_index)
    unless s_id =~ /\AS\d+\z/
      result[:failed] += 1
      result[:errors] << "Fila #{row_index}: Formato de S ID inválido (debe ser 'S' seguido de números)"
      raise "Formato de S ID inválido"
    end
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

  def normalize_row_keys(hash)
    hash.transform_keys { |k| k.to_s.downcase.strip.gsub(/[(*)]/, '').strip }
  end

  def find_value(attributes, possible_keys)
    possible_keys.each do |key|
      value = attributes[key]
      return value if value.present?
    end
    nil
  end

  def detect_separator(content)
    first_line = content.lines.first.to_s
    first_line.include?(';') ? ';' : ','
  end

  def valid_import_file?(file)
    extension = File.extname(file.original_filename).downcase
    return true if extension == '.csv'

    Rails.logger.error "Extensión de archivo inválida: #{extension}"
    false
  end

  def set_import_flash_message(result)
    if result[:errors].any?
      set_error_flash_message(result)
    else
      set_success_flash_message(result)
    end
  end

  def set_error_flash_message(result)
    message = l('plugin_sites_manager.messages.import_partial',
                imported: result[:imported],
                updated: result[:updated],
                failed: result[:failed])
    
    error_messages = format_error_messages(result[:errors])
    
    flash[:error] = message
    flash[:warning] = error_messages.html_safe
  end

  def set_success_flash_message(result)
    flash[:notice] = l('plugin_sites_manager.messages.import_success',
                      imported: result[:imported],
                      updated: result[:updated])
  end

  def format_error_messages(errors)
    error_messages = errors.group_by { |error| error[/^.*?:/] || 'Otros:' }
    error_messages.map do |type, messages|
      "<strong>#{type}</strong><ul>" +
      messages.map { |e| "<li>#{e.sub(type, '')}</li>" }.join + 
      "</ul>"
    end.join
  end

  def handle_error(error)
    log_error("Error en operación de sitios", error)
    flash[:error] = error.message
    redirect_to sites_path
  end

  def handle_template_error(error)
    log_error("Error generando plantilla", error)
    flash[:error] = l('plugin_sites_manager.messages.template_generation_error')
    redirect_to import_sites_path
  end

  def handle_export_error(error)
    log_error("Error exportando sitios", error)
    flash[:error] = l('plugin_sites_manager.messages.export_error')
    redirect_to sites_path
  end

  def handle_row_error(error, result, row_index)
    result[:failed] += 1
    result[:errors] << "Fila #{row_index}: Error - #{error.message}"
  end

  def log_error(message, error)
    Rails.logger.error "#{message}: #{error.message}\n#{error.backtrace.join("\n")}"
  end

  def unauthorized_error
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def missing_file_error
    flash.now[:error] = l('plugin_sites_manager.messages.no_file')
    render :import
  end

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
      :electrificadora, :nic, :zona_operativa,
      :campo_adicional_4, :campo_adicional_5
    )
  end

  def build_site_query
    @query = params[:search].present? ? { search: params[:search] } : {}
  end

  def verify_sites_manager_access
    unless User.current.admin?
      flash[:error] = l('plugin_sites_manager.messages.access_denied')
      redirect_to(home_url)
      return false
    end
  end

  def require_admin
    return unless require_login
    unless User.current.admin?
      render_403
      return false
    end
  end
end