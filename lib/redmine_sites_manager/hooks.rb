module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    # Incluir CSS y JS en el header de todas las páginas
    def view_layouts_base_html_head(context={})
      stylesheet_link_tag('sites_manager', plugin: 'redmine_sites_manager') +
      javascript_include_tag('sites_manager_admin', plugin: 'redmine_sites_manager')
    end

    # Hook para agregar el campo de búsqueda de sitios en el formulario de incidencias
    def view_issues_form_details_top(context={})
      issue = context[:issue]
      return '' unless issue.new_record? || issue.status_id.to_s == '1' # Solo para nuevas incidencias o en estado "Creado"
      
      <<-HTML
        <div class="sites-search-container">
          <p>
            <label>#{l('plugin_sites_manager.sites.search_label')}</label>
            <input type="text" id="sites-search-field" class="sites-autocomplete" 
                   placeholder="#{l('plugin_sites_manager.sites.search_placeholder')}" />
            <span class="sites-clear-btn" title="#{l('plugin_sites_manager.sites.clear_selection')}">×</span>
          </p>
          <script>
            $(function() {
              initializeSitesSearch();
            });
          </script>
        </div>
      HTML
    end

    # Hook para agregar campos personalizados adicionales específicos de sitios
    def view_custom_fields_form_upper_box(context={})
      <<-HTML
        <p>
          <label>#{l('plugin_sites_manager.custom_fields.site_related')}</label>
          #{check_box_tag 'custom_field[site_related]', '1', context[:custom_field].site_related}
        </p>
      HTML
    end

    # Hook para el menú de administración
    def view_layouts_base_sidebar(context={})
    return '' unless User.current.admin? && context[:controller].is_a?(AdminController) && context[:controller].action_name == 'index'
  
    <<-HTML
      <div class="sites-manager-menu">
        <h3>#{l('plugin_sites_manager.title')}</h3>
        <ul>
          <li>
            #{link_to l('plugin_sites_manager.sites.list'), 
                     { controller: 'sites', action: 'index' },
                     class: 'icon icon-sites'}
          </li>
          <li>
            #{link_to l('plugin_sites_manager.sites.import'),
                     { controller: 'sites', action: 'import' },
                     class: 'icon icon-import'}
          </li>
        </ul>
      </div>
    HTML
  end
    # Hook para agregar campos personalizados en la vista de detalles de incidencia
    def view_issues_show_details_bottom(context={})
      issue = context[:issue]
      site = FlmSite.find_by(id: issue.custom_field_value('site_id'))
      
      return unless site
      
      <<-HTML
        <div class="sites-details">
          <hr />
          <h3>#{l('plugin_sites_manager.sites.details')}</h3>
          <div class="sites-info">
            <p>
              <strong>#{l('plugin_sites_manager.field_s_id')}:</strong>
              #{h(site.s_id)}
            </p>
            <p>
              <strong>#{l('plugin_sites_manager.field_nom_sitio')}:</strong>
              #{h(site.nom_sitio)}
            </p>
            <p>
              <strong>#{l('plugin_sites_manager.field_direccion')}:</strong>
              #{h(site.direccion)}
            </p>
            <p>
              <strong>#{l('plugin_sites_manager.field_municipio')}:</strong>
              #{h(site.municipio)}
            </p>
            <p>
              <strong>#{l('plugin_sites_manager.field_jerarquia')}:</strong>
              #{h(site.jerarquia)}
            </p>
            <p>
              <strong>#{l('plugin_sites_manager.field_fijo_variable')}:</strong>
              #{h(site.fijo_variable)}
            </p>
            <p>
              <strong>#{l('plugin_sites_manager.field_coordinador')}:</strong>
              #{h(site.coordinador)}
            </p>
          </div>
        </div>
      HTML
    end

    # Hook para agregar JS específico en ciertas páginas
    def view_layouts_base_body_bottom(context={})
      return unless context[:controller] && 
                   context[:controller].is_a?(IssuesController) && 
                   ['new', 'create', 'edit', 'update'].include?(context[:controller].action_name)
      
      javascript_tag <<-JS
        $(function() {
          window.sitesManagerSettings = {
            searchUrl: '#{url_for(controller: 'sites', action: 'search', format: 'json')}',
            clearUrl: '#{url_for(controller: 'sites', action: 'clear', format: 'json')}',
            customFieldMappings: #{Setting.plugin_redmine_sites_manager['custom_field_mappings'].to_json}
          };
        });
      JS
    end
  end
  
  # Registrar los hooks para assets
  class SitesManagerHooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head,
              partial: 'sites_manager/html_head'
  end
end
