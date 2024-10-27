class SitesController < ApplicationController
  unloadable
  
  before_action :require_login
  before_action :require_admin, except: [:search]
  before_action :find_site, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :build_site_query, only: [:index]
  
  helper :sort
  include SortHelper
  
  def index
    sort_init 's_id', 'asc'
    sort_update %w(s_id nom_sitio depto municipio jerarquia_definitiva fijo_variable)
    
    @limit = per_page_option
    
    scope = FlmSite.order(created_at: :desc)
    
    # Búsqueda simple si no se usa SiteQuery
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      scope = scope.where("LOWER(s_id) LIKE ? OR LOWER(nom_sitio) LIKE ?", 
                         search_term, search_term)
    end
    
    @site_count = scope.count
    @site_pages = Paginator.new @site_count, @limit, params['page']
    @offset ||= @site_pages.offset
    @sites = scope.limit(@limit).offset(@offset)
    
    # Cargar datos para filtros
    @departamentos = FlmSite.distinct.pluck(:depto).compact.sort
    @municipios = FlmSite.distinct.pluck(:municipio).compact.sort
    @jerarquias = FlmSite.distinct.pluck(:jerarquia_definitiva).compact.sort
    
    respond_to do |format|
      format.html
      format.json { render json: { sites: @sites, total: @site_count } }
      format.api
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.api
      format.json { render json: @site.to_json_for_details }
    end
  end
  private

  def new
    @site = FlmSite.new
    @departamentos = FlmSite.distinct.pluck(:depto).compact.sort
    @municipios = FlmSite.distinct.pluck(:municipio).compact.sort
  end
  
  def create
    @site = FlmSite.new(site_params)
    
    respond_to do |format|
      if @site.save
        format.html {
          flash[:notice] = l(:notice_successful_create)
          redirect_to sites_path
        }
        format.json { render json: @site.to_json_for_details, status: :created }
      else
        @departamentos = FlmSite.distinct.pluck(:depto).compact.sort
        @municipios = FlmSite.distinct.pluck(:municipio).compact.sort
        format.html { render :new }
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
    @site = FlmSite.find(params[:id])
    @departamentos = FlmSite.distinct.pluck(:depto).compact.sort
    @municipios = FlmSite.distinct.pluck(:municipio).compact.sort
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def update
    @site = FlmSite.find(params[:id])
    if @site.update(site_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to sites_path
    else
      @departamentos = FlmSite.distinct.pluck(:depto).compact.sort
      @municipios = FlmSite.distinct.pluck(:municipio).compact.sort
      render :edit
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  private
  
  def destroy
    begin
      if @site.destroy
        flash[:notice] = l(:notice_successful_delete)
      else
        flash[:error] = l('plugin_sites_manager.messages.delete_error')
      end
    rescue => e
      flash[:error] = l('plugin_sites_manager.messages.delete_error_details', message: e.message)
    end
    
    respond_to do |format|
      format.html { redirect_to sites_path }
      format.json { head :no_content }
    end
  end

  def import
    if request.post? && params[:file].present?
      begin
        result = FlmSite.import_from_excel(params[:file].path)
        
        if result[:failed] > 0
          flash[:warning] = l('plugin_sites_manager.messages.import_partial',
                            imported: result[:imported],
                            updated: result[:updated],
                            failed: result[:failed])
          session[:import_errors] = result[:errors]
        else
          flash[:notice] = l('plugin_sites_manager.messages.import_success',
                           imported: result[:imported],
                           updated: result[:updated])
        end
      rescue => e
        flash[:error] = "#{l('plugin_sites_manager.messages.import_error')}: #{e.message}"
      end
      
      redirect_to sites_path
    else
      render :import
    end
  end
  
  def search
    term = params[:term].to_s.strip.downcase
    scope = FlmSite.active
    
    if term.present?
      scope = scope.where("LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term OR LOWER(identificador) LIKE :term", 
                         term: "%#{term}%")
    end
    
    if params[:depto].present?
      scope = scope.by_depto(params[:depto])
    end
    
    if params[:municipio].present?
      scope = scope.by_municipio(params[:municipio])
    end
    
    @sites = scope.limit(10)
    
    respond_to do |format|
      format.json { render json: @sites.map(&:to_json_for_autocomplete) }
    end
  end
  
  def toggle_status
    respond_to do |format|
      if @site.toggle_status!
        format.html {
          flash[:notice] = l('plugin_sites_manager.messages.status_updated')
          redirect_to sites_path
        }
        format.json { render json: { status: @site.active, success: true } }
      else
        format.html {
          flash[:error] = l('plugin_sites_manager.messages.status_update_failed')
          redirect_to sites_path
        }
        format.json { render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end
  
  def bulk_update
    if params[:ids].present? && params[:action_name].present?
      begin
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
  
  def site_params
    params.require(:flm_site).permit(
      :s_id,
      :depto,
      :municipio,
      :nom_sitio,
      :direccion,
      :identificador,
      :jerarquia_definitiva,
      :fijo_variable,
      :coordinador,
      :campo_adicional_1,
      :campo_adicional_2,
      :campo_adicional_3,
      :campo_adicional_4,
      :campo_adicional_5
    )
  end
  
  def build_site_query
    @query = params[:search].present? ? 
      { search: params[:search] } : 
      {}
  end
  def export_to_csv(sites)
    require 'csv'
    
    CSV.generate do |csv|
      # Header
      csv << [
        'S ID',
        l('plugin_sites_manager.fields.depto'),
        l('plugin_sites_manager.fields.municipio'),
        l('plugin_sites_manager.fields.nom_sitio'),
        l('plugin_sites_manager.fields.direccion'),
        l('plugin_sites_manager.fields.identificador'),
        l('plugin_sites_manager.fields.jerarquia_definitiva'),
        l('plugin_sites_manager.fields.fijo_variable'),
        l('plugin_sites_manager.fields.coordinador'),
        l('plugin_sites_manager.fields.status')
      ]
      
      # Data
      sites.each do |site|
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
          site.active? ? l(:general_text_yes) : l(:general_text_no)
        ]
      end
    end
  end
  
  def export_to_xlsx(sites)
    p = Axlsx::Package.new
    wb = p.workbook
    
    wb.add_worksheet(name: "Sites") do |sheet|
      # Styles
      styles = wb.styles
      header = styles.add_style(b: true)
      
      # Header
      sheet.add_row [
        'S ID',
        l('plugin_sites_manager.fields.depto'),
        l('plugin_sites_manager.fields.municipio'),
        l('plugin_sites_manager.fields.nom_sitio'),
        l('plugin_sites_manager.fields.direccion'),
        l('plugin_sites_manager.fields.identificador'),
        l('plugin_sites_manager.fields.jerarquia_definitiva'),
        l('plugin_sites_manager.fields.fijo_variable'),
        l('plugin_sites_manager.fields.coordinador'),
        l('plugin_sites_manager.fields.status')
      ], style: header
      
      # Data
      sites.each do |site|
        sheet.add_row [
          site.s_id,
          site.depto,
          site.municipio,
          site.nom_sitio,
          site.direccion,
          site.identificador,
          site.jerarquia_definitiva,
          site.fijo_variable,
          site.coordinador,
          site.active? ? l(:general_text_yes) : l(:general_text_no)
        ]
      end
    end
    
    p.to_stream.read
  end
end