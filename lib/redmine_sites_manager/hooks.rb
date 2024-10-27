module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    # Incluir CSS y JS en el header de todas las páginas
    def view_layouts_base_html_head(context={})
      stylesheet = stylesheet_link_tag('sites_manager', :plugin => 'redmine_sites_manager')
      javascript = javascript_include_tag('sites_manager_admin', :plugin => 'redmine_sites_manager')
      "#{stylesheet}\n#{javascript}".html_safe
    end

    # Hook para agregar el campo de búsqueda de sitios en el formulario de incidencias
    def view_issues_form_details_top(context={})
    return '' unless context[:issue]

    translation_label = l('plugin_sites_manager.search.label')
    translation_placeholder = l('plugin_sites_manager.search.placeholder')
    
    html = <<-HTML
      <div class="sites-search-container">
        <div class="field">
          <label>#{translation_label}</label>
          <input type="text" 
                 id="sites-search-field" 
                 class="sites-autocomplete" 
                 placeholder="#{translation_placeholder}"
                 autocomplete="off" />
          <span class="sites-clear-btn">×</span>
        </div>
      </div>
    HTML
    
    html.html_safe
  end

  render_on :view_layouts_base_html_head do
    javascript_tag do
      <<-JS
      $(document).ready(function() {
        var translations = {
          searchLabel: '#{j l('plugin_sites_manager.search.label')}',
          searchPlaceholder: '#{j l('plugin_sites_manager.search.placeholder')}',
          noResults: '#{j l('plugin_sites_manager.search.no_results')}',
          searching: '#{j l('plugin_sites_manager.search.searching')}'
        };

        if ($('#sites-search-field').length) {
          $('#sites-search-field').attr('placeholder', translations.searchPlaceholder);
        }
      });
      JS
    end
  end

    # Hook para agregar campos personalizados adicionales específicos de sitios
    def view_custom_fields_form_upper_box(context={})
    return '' unless context[:custom_field]
    
    # Verificar si el campo personalizado tiene el método `site_related`
    if context[:custom_field].respond_to?(:site_related)
      <<-HTML.html_safe
        <div class="site-related-fields">
          <p>
            <label>#{l('plugin_sites_manager.custom_fields.site_related')}</label>
            #{check_box_tag 'custom_field[site_related]', '1', 
              context[:custom_field].site_related,
              class: 'site-related-checkbox'}
          </p>
          <p class="site-field-info" style="display: none;">
            <em class="info">#{l('plugin_sites_manager.custom_fields.site_related_info')}</em>
          </p>
        </div>
      HTML
    else
      # Si no tiene `site_related`, retorna un string vacío sin renderizar contenido adicional
      ''
    end
  end
  

    # Hook para agregar campos personalizados en la vista de detalles de incidencia
    def view_issues_show_details_bottom(context={})
      issue = context[:issue]
      site = find_related_site(issue)
      
      return '' unless site

      render_site_details(site)
    end

    # Hook para agregar JS específico en ciertas páginas
    def view_layouts_base_body_bottom(context={})
      return unless should_include_js?(context)
      
      javascript_tag <<-JS
        $(function() {
          window.sitesManagerSettings = {
            searchUrl: '#{sites_search_url}',
            customFieldMappings: #{get_custom_field_mappings.to_json},
            translations: #{get_translations.to_json},
            fieldMapping: #{get_field_mapping.to_json}
          };

          // Inicializar la búsqueda si estamos en el formulario correcto
          if ($('#sites-search-field').length) {
            initializeSitesSearch();
          }
        });
      JS
    end

    private

    def valid_context?(context)
      context[:controller] && 
      (context[:controller].is_a?(IssuesController) || 
       context[:controller].is_a?(SitesController))
    end

    def show_site_search?(issue)
      issue && (issue.new_record? || issue.status_id.to_s == '1')
    end

    def sites_search_url
      url_for(
        controller: 'sites',
        action: 'search',
        format: 'json',
        only_path: true
      )
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
        25=> 'electrificadora',
        26=> 'nic'
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

    def find_related_site(issue)
      site_id = issue.custom_field_value('site_id')
      FlmSite.find_by(id: site_id) if site_id.present?
    end

    def render_site_details(site)
      <<-HTML.html_safe
        <div class="sites-details">
          <hr />
          <h3>#{l('plugin_sites_manager.sites.details')}</h3>
          <div class="sites-info">
            #{render_site_field(site, 's_id')}
            #{render_site_field(site, 'nom_sitio')}
            #{render_site_field(site, 'direccion')}
            #{render_site_field(site, 'municipio')}
            #{render_site_field(site, 'jerarquia_definitiva')}
            #{render_site_field(site, 'fijo_variable')}
            #{render_site_field(site, 'coordinador')}
            #{render_site_field(site, 'electrificadora')}
            #{render_site_field(site, 'nic')}
          </div>
        </div>
      HTML
    end

    def render_site_field(site, field)
      return '' unless site.respond_to?(field)
      value = site.send(field)
      return '' if value.blank?

      <<-HTML
        <p>
          <strong>#{l("plugin_sites_manager.fields.#{field}")}:</strong>
          #{h(value)}
        </p>
      HTML
    end

    def render_initialization_script
      <<-HTML
        <script>
          $(function() {
            if (typeof initializeSitesSearch !== 'undefined') {
              initializeSitesSearch();
            }
          });
        </script>
      HTML
    end

    def should_include_js?(context)
      context[:controller] && 
      context[:controller].is_a?(IssuesController) && 
      ['new', 'create', 'edit', 'update'].include?(context[:controller].action_name)
    end
  end
  
  # Registrar los hooks para assets
  class SitesManagerHooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head,
              partial: 'sites_manager/html_head'
  end
end