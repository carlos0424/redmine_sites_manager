class SitesController < ApplicationController
  unloadable
  
  before_action :require_login
  before_action :require_admin, except: [:search]
  before_action :find_site, only: [:show, :edit, :update, :destroy, :toggle_status]
  
  helper :sort
  include SortHelper
  def index
    @sites = FlmSite.order(created_at: :desc) # Aseguramos que @sites obtenga todos los registros
  end
  def index
    @limit = per_page_option
    
    scope = FlmSite.order(created_at: :desc)
    
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      scope = scope.where("LOWER(s_id) LIKE ? OR LOWER(nom_sitio) LIKE ?", 
                         search_term, search_term)
    end
    
    @site_count = scope.count
    @site_pages = Paginator.new @site_count, @limit, params['page']
    @offset ||= @site_pages.offset
    @sites = scope.limit(@limit).offset(@offset)
    
    respond_to do |format|
      format.html
      format.json { render json: { sites: @sites, total: @site_count } }
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.json { render json: @site }
    end
  end

  def new
    @site = FlmSite.new
  end
  
  def create
    @site = FlmSite.new(site_params)
    
    if @site.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to sites_path
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @site.update(site_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to sites_path
    else
      render :edit
    end
  end
  
  def destroy
    @site.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to sites_path
  end

  def import
    if request.post? && params[:file].present?
      begin
        FlmSite.import_from_excel(params[:file].path)
        flash[:notice] = l('plugin_sites_manager.messages.import_success')
      rescue => e
        flash[:error] = "#{l('plugin_sites_manager.messages.import_error')}: #{e.message}"
      end
      redirect_to sites_path
    else
      render :import
    end
  end
  
  def search
    term = params[:term].to_s.downcase
    @sites = FlmSite.where("LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term", 
                          term: "%#{term}%").limit(10)
    
    respond_to do |format|
      format.json { 
        render json: @sites.map { |site| 
          {
            id: site.id,
            label: "#{site.s_id} - #{site.nom_sitio}",
            value: site.nom_sitio,
            sitio_data: {
              s_id: site.s_id,
              depto: site.depto,
              municipio: site.municipio,
              direccion: site.direccion,
              identificador: site.identificador,
              jerarquia: site.jerarquia,
              definitiva: site.definitiva,
              fijo_variable: site.fijo_variable,
              coordinador: site.coordinador
            }
          }
        }
      }
    end
  end
  
  def toggle_status
    new_status = @site.active? ? 'inactive' : 'active'
    
    if @site.update(status: new_status)
      respond_to do |format|
        format.html {
          flash[:notice] = l('plugin_sites_manager.messages.status_updated')
          redirect_to sites_path
        }
        format.json { render json: { status: new_status } }
      end
    else
      respond_to do |format|
        format.html {
          flash[:error] = l('plugin_sites_manager.messages.status_update_failed')
          redirect_to sites_path
        }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def find_site
    @site = FlmSite.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def site_params
    params.require(:site).permit(
      :s_id,
      :depto,
      :municipio,
      :nom_sitio,
      :direccion,
      :identificador,
      :jerarquia,
      :definitiva,
      :fijo_variable,
      :coordinador,
      :status
    )
  end
end
