module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    # Incluir CSS y JS en el header de todas las páginas
    def view_layouts_base_html_head(context = {})
      stylesheet = stylesheet_link_tag('sites_manager', plugin: 'redmine_sites_manager')
      javascript = javascript_include_tag('sites_manager_admin', plugin: 'redmine_sites_manager')
      "#{stylesheet}\n#{javascript}".html_safe
    end

    # Hook para agregar el campo de búsqueda de sitios en el formulario de incidencias
    def view_issues_form_details_top(context = {})
      html = <<-HTML
        <div class="sites-search-container">
          <p class="site-search-wrapper">
            <label>#{l('plugin_sites_manager.sites.search_label')}</label>
            <input type="text" 
                   id="sites-search-field" 
                   class="sites-autocomplete ui-autocomplete-input" 
                   placeholder="#{l('plugin_sites_manager.search.placeholder')}" 
                   autocomplete="off" />
            <span class="sites-clear-btn" 
                  title="#{l('plugin_sites_manager.sites.clear_selection')}">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16" height="16">
                <path d="M6 18L18 6M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </span>
          </p>
        </div>
      HTML
      
      html.html_safe
    end

    # Hook para agregar JS específico en ciertas páginas
    def view_layouts_base_body_bottom(context = {})
      return unless should_include_js?(context)
      
      javascript_tag <<-JS
        $(document).ready(function() {
          window.sitesManagerSettings = {
            searchUrl: '#{sites_search_url}',
            customFieldMappings: #{get_custom_field_mappings.to_json},
            translations: #{get_translations.to_json},
            fieldMapping: #{get_field_mapping.to_json}
          };
          
          if (typeof initializeSitesSearch !== 'undefined') {
            initializeSitesSearch();
          }
        });
      JS
    end

    private

    def sites_search_url
      url_for(controller: 'sites', action: 'search', format: 'json', only_path: true)
    end

    def get_custom_field_mappings
      Setting.plugin_redmine_sites_manager['custom_fields_mapping'] || {}
    end

    def get_field_mapping
      {
        1 => 's_id',
        5 => 'nom_sitio',
        8 => 'identificador',
        10 => 'depto',
        2 => 'municipio',
        3 => 'direccion',
        6 => 'jerarquia_definitiva',
        7 => 'fijo_variable',
        9 => 'coordinador',
        25 => 'electrificadora',
        26 => 'nic',
        32 => 'zona_operativa'
      }
    end

    def get_translations
      {
        noResults: l('plugin_sites_manager.search.no_results'),
        searching: l('plugin_sites_manager.search.searching'),
        placeholder: l('plugin_sites_manager.search.placeholder'),
        clearSelection: l('plugin_sites_manager.sites.clear_selection')
      }
    end

    def should_include_js?(context)
      return false unless context[:controller]
      return false unless context[:controller].is_a?(IssuesController)
      
      # Incluir JS en todas las acciones relevantes del controlador de issues
      %w[new create edit update].include?(context[:controller].action_name)
    end
  end
  
  # Registrar los hooks para assets
  class SitesManagerHooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head, partial: 'sites_manager/html_head'
  end
end
