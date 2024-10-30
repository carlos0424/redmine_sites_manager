# app/controllers/sites_controller.rb
class SitesController < ApplicationController
  unloadable

  before_action :require_login
  before_action :require_admin, except: [:search, :autocomplete]
  before_action :find_site, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :load_site_collections, only: [:new, :create, :edit, :update]
  skip_before_action :verify_authenticity_token, only: [:search]
  before_action :verify_sites_manager_access, except: [:search, :autocomplete]

  helper :sort
  include SortHelper

  EXPORTABLE_COLUMNS = [
    'S ID', 'Departamento', 'Municipio', 'Nombre Sitio', 'Dirección',
    'Identificador', 'Jerarquía Definitiva', 'Fijo/Variable', 'Coordinador',
    'Electrificadora', 'NIC', 'zona_operativa', 'Campo Adicional 4',
    'Campo Adicional 5'
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
      format.csv { export_to_csv }
      format.xlsx { export_to_xlsx }
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
    save_site(:create)
  end

  def edit
  end

  def update
    @site.attributes = site_params
    save_site(:update)
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
      result = import_sites_from_file
      set_import_flash_message(result)
      redirect_to sites_path
    rescue StandardError => e
      flash.now[:error] = "#{l('plugin_sites_manager.messages.import_error')}: #{e.message}"
      render :import
    end
  end

  def export
    begin
      @sites = build_export_scope
      send_data generate_csv(@sites),
                filename: "sitios_#{Date.today.strftime('%Y%m%d')}.csv",
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue StandardError => e
      log_error("Error exportando sitios", e)
      flash[:error] = l('plugin_sites_manager.messages.export_error')
      redirect_to sites_path
    end
  end

  private

  def save_site(action)
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
    scope.where("LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term OR 
                LOWER(municipio) LIKE :term OR LOWER(depto) LIKE :term", term: term)
  end

  def generate_csv(sites)
    require 'csv'
    bom = "\xEF\xBB\xBF"
    
    csv_data = CSV.generate(col_sep: ';') do |csv|
      csv << EXPORTABLE_COLUMNS
      sites.find_each do |site|
        csv << site_to_csv_row(site)
      end
    end

    bom + csv_data
  end

  def site_to_csv_row(site)
    [
      site.s_id, site.depto, site.municipio, site.nom_sitio, site.direccion,
      site.identificador, site.jerarquia_definitiva, site.fijo_variable,
      site.coordinador, site.electrificadora, site.nic, site.zona_operativa,
      site.campo_adicional_4, site.campo_adicional_5
    ]
  end

  def unauthorized_error
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def missing_file_error
    flash.now[:error] = l('plugin_sites_manager.messages.no_file')
    render :import
  end

  def handle_error(error)
    log_error("Error en operación de sitios", error)
    flash[:error] = error.message
    redirect_to sites_path
  end

  def log_error(message, error)
    Rails.logger.error "#{message}: #{error.message}\n#{error.backtrace.join("\n")}"
  end

  def require_admin
    return unless require_login
    render_403 unless User.current.admin?
  end

  def verify_sites_manager_access
    unless User.current.admin?
      flash[:error] = l('plugin_sites_manager.messages.access_denied')
      redirect_to(home_url)
      return false
    end
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
      :jerarquia_definitiva, :fijo_variable, :coordinador, :electrificadora,
      :nic, :zona_operativa, :campo_adicional_4, :campo_adicional_5
    )
  end
end