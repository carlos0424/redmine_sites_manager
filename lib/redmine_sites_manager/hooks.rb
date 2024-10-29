module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    # Incluir CSS y JS en el header de todas las páginas
    def view_layouts_base_html_head(context={})
    return unless should_include_assets?(context)
    
    stylesheet = stylesheet_link_tag('sites_manager', :plugin => 'redmine_sites_manager')
    javascript = [
      javascript_include_tag('jquery-ui.min', :plugin => 'redmine_sites_manager'),
      javascript_include_tag('sites_manager_admin', :plugin => 'redmine_sites_manager')
    ].join("\n")
    
    styles = <<-CSS
      <style>
        .sites-search-container {
          margin-bottom: 1em;
        }
        .site-search-wrapper {
          display: flex;
          align-items: center;
          position: relative;
          margin-bottom: 10px;
        }
        .site-search-wrapper label {
          float: left;
          margin-right: 10px;
          width: 170px;
          text-align: right;
        }
        #sites-search-field {
          width: 250px;
          padding: 3px 25px 3px 6px;
          border: 1px solid #ccc;
          border-radius: 3px;
        }
        .sites-clear-btn {
          position: absolute;
          right: 5px;
          top: 50%;
          transform: translateY(-50%);
          cursor: pointer;
          padding: 4px;
          color: #666;
          z-index: 100;
        }
        .sites-clear-btn:hover {
          color: #333;
        }
        .ui-autocomplete {
          max-height: 300px;
          overflow-y: auto;
          overflow-x: hidden;
          z-index: 1000;
        }
      </style>
    CSS

    "#{stylesheet}\n#{javascript}\n#{styles}".html_safe
  end

    # Hook para agregar el campo de búsqueda de sitios en el formulario de incidencias
    def view_issues_form_details_top(context={})
      html = <<-HTML
        <div class="sites-search-container">
          <p class="site-search-wrapper">
            <label>#{l(:field_buscar_sitios)}</label>
            <input type="text" 
                   id="sites-search-field" 
                   class="sites-autocomplete" 
                   placeholder="#{l(:text_buscar_sitio_placeholder)}" 
                   autocomplete="off" />
            <span class="sites-clear-btn" 
                  title="#{l(:button_clear)}">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16" height="16">
                <path d="M6 18L18 6M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </span>
          </p>
        </div>
      HTML
      
      html.html_safe
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
      
       #  podemos permitir la edición si está en ciertos estados
       allowed_statuses = [1] # IDs de los estados permitidos
       return '' unless issue.new_record? || allowed_statuses.include?(issue.status_id)
       
      render_site_details(site)
    end

    # Hook para agregar JS específico en ciertas páginas
     def view_layouts_base_body_bottom(context={})
      return unless should_include_js?(context)
      
      javascript_tag <<-JS
        $(function() {
          window.sitesManagerSettings = {
            searchUrl: '#{sites_search_url}',
            fieldMapping: #{get_field_mapping.to_json}
          };

          initSiteSearch();
          
          // Manejar cambio de tracker
          $(document).on('change', '#issue_tracker_id', function() {
            setTimeout(initSiteSearch, 100);
          });
        });
      JS
    end

    private

    def should_include_assets?(context)
      return false unless context[:controller]
      [IssuesController, SitesController].any? { |klass| context[:controller].is_a?(klass) }
    end

    def valid_context?(context)
      context[:controller] && 
      (context[:controller].is_a?(IssuesController) || 
       context[:controller].is_a?(SitesController))
    end

    def show_site_search?(issue)
      return true if issue.nil? || issue.new_record?
      return true if issue.status_id == 1 # Estado "Creado"
      false
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
        26=> 'nic',
        32=> 'zona_operativa'
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
            #{render_site_field(site, 'zona_operativa')}
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
            const $searchField = $('#sites-search-field');
            const $clearBtn = $('.sites-clear-btn');
    
            // Mostrar u ocultar el botón de limpiar según el contenido del campo
            $searchField.on('input', function() {
              if ($(this).val()) {
                $clearBtn.show();
              } else {
                $clearBtn.hide();
              }
            });
    
            // Limpiar el campo de búsqueda al hacer clic en el botón de limpiar
            $clearBtn.on('click', function() {
              $searchField.val('').trigger('input').focus();
            });
    
            // Ocultar el botón de limpiar inicialmente
            if (!$searchField.val()) {
              $clearBtn.hide();
            }
    
            // Inicializar búsqueda si está en el campo correspondiente
            if (typeof initializeSitesSearch !== 'undefined') {
              initializeSitesSearch();
            }
          });
        </script>
      HTML
    end

   
    def should_include_js?(context)
      return false unless context[:controller]
      return false unless context[:controller].is_a?(IssuesController)
      ['new', 'create', 'edit', 'update'].include?(context[:controller].action_name)
    end
  end
  
  # Registrar los hooks para assets
  class SitesManagerHooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head,
              partial: 'sites_manager/html_head'
  end
end