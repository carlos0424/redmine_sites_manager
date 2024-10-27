class SitesController < ApplicationController
  unloadable

  # Requerir login y acceso de administrador para todas las acciones excepto 'search'
  before_action :require_login
  before_action :require_admin, except: [:search, :index, :show]
  before_action :find_site, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :load_site_collections, only: [:new, :create, :edit, :update]
  before_action :build_site_query, only: [:index]

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
      format.csv { send_data export_to_csv(@sites), filename: "sites-#{Date.today}.csv" }
      format.xlsx { send_data export_to_xlsx(@sites), filename: "sites-#{Date.today}.xlsx" }
    end
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
        format.html { render :new }
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

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

  def import
    if request.post? && params[:file].present?
      result = import_sites_from_file
      set_import_flash_message(result)
      redirect_to sites_path
    else
      render :import
    end
  end

  def search
    @sites = FlmSite.where(
      "LOWER(s_id) LIKE :term OR 
       LOWER(nom_sitio) LIKE :term OR 
       LOWER(identificador) LIKE :term OR 
       LOWER(municipio) LIKE :term OR 
       LOWER(direccion) LIKE :term OR 
       LOWER(depto) LIKE :term", 
      term: "%#{params[:term].downcase}%"
    ).limit(10)

    respond_to do |format|
      format.json { 
        render json: @sites.map { |site| 
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
              coordinador: site.coordinador
            }
          }
        }
      }
    end
  end
end

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
    if params[:ids].present? && params[:action_name].present?
      perform_bulk_update
    else
      flash[:error] = l('plugin_sites_manager.messages.no_selection')
    end

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
      :campo_adicional_1, :campo_adicional_2, :campo_adicional_3,
      :campo_adicional_4, :campo_adicional_5
    )
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
    FlmSite.import_from_excel(params[:file].path)
  rescue => e
    { error: e.message }
  end

  def set_import_flash_message(result)
    if result[:error]
      flash[:error] = "#{l('plugin_sites_manager.messages.import_error')}: #{result[:error]}"
    elsif result[:failed].to_i > 0
      flash[:warning] = l('plugin_sites_manager.messages.import_partial', imported: result[:imported], updated: result[:updated], failed: result[:failed])
      session[:import_errors] = result[:errors]
    else
      flash[:notice] = l('plugin_sites_manager.messages.import_success', imported: result[:imported], updated: result[:updated])
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
    end
  rescue => e
    flash[:error] = e.message
  end
end
