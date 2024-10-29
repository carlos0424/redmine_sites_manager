module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    # Incluir CSS y JS en el header de todas las páginas
    def view_layouts_base_html_head(context={})
      return unless should_include_assets?(context)
      
      stylesheet = stylesheet_link_tag('sites_manager', :plugin => 'redmine_sites_manager')
      javascript = [
        javascript_include_tag('sites_manager_admin', :plugin => 'redmine_sites_manager'),
        javascript_include_tag('jquery-ui.min', :plugin => 'redmine_sites_manager')
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
          .ui-menu-item {
            padding: 5px 8px;
            border-bottom: 1px solid #eee;
          }
          .ui-menu-item:last-child {
            border-bottom: none;
          }
          .autocomplete-item strong {
            display: block;
            color: #333;
          }
          .autocomplete-item small {
            color: #666;
            font-size: 0.9em;
          }
          .sites-details {
            margin-top: 15px;
            padding: 10px;
            background: #f9f9f9;
            border: 1px solid #e0e0e0;
            border-radius: 3px;
          }
          .campo-variable {
            background-color: #fff3cd;
            border-color: #ffeeba;
          }
          .campo-fijo {
            background-color: #d4edda;
            border-color: #c3e6cb;
          }
        </style>
      CSS

      script = <<-JAVASCRIPT
        <script>
          window.SITES_MANAGER = {
            labels: {
              searchPlaceholder: "#{l(:text_buscar_sitio_placeholder)}",
              noResults: "#{l(:text_no_results)}",
              searching: "#{l(:text_searching)}"
            },
            urls: {
              search: "#{sites_search_url}"
            },
            fieldMapping: #{get_field_mapping.to_json}
          };
        </script>
      JAVASCRIPT

      "#{stylesheet}\n#{javascript}\n#{styles}\n#{script}".html_safe
    end

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

    def view_custom_fields_form_upper_box(context={})
      return '' unless context[:custom_field]
      
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
        ''
      end
    end

    def view_issues_show_details_bottom(context={})
      issue = context[:issue]
      site = find_related_site(issue)
      return '' unless site
      
      render_site_details(site)
    end

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

          // Reinicializar cuando cambia el tracker
          $(document).on('change', '#issue_tracker_id', function() {
            setTimeout(function() {
              if ($('#sites-search-field').length) {
                initializeSitesSearch();
              }
            }, 500);
          });
        });
      JS
    end

    private

    def should_include_assets?(context)
      return false unless context[:controller]
      [IssuesController, SitesController].any? { |klass| context[:controller].is_a?(klass) }
    end

    def should_include_js?(context)
      return false unless context[:controller]
      return false unless context[:controller].is_a?(IssuesController)
      
      ['new', 'create', 'edit', 'update'].include?(context[:controller].action_name)
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
        noResults: l(:text_no_results),
        searching: l(:text_searching),
        placeholder: l(:text_buscar_sitio_placeholder),
        clearSelection: l(:button_clear)
      }
    end

    def find_related_site(issue)
      site_id = issue.custom_field_value('site_id')
      FlmSite.find_by(id: site_id) if site_id.present?
    end

    def render_site_details(site)
      return '' unless site

      <<-HTML.html_safe
        <div class="sites-details">
          <hr />
          <h3>#{l(:field_site_details)}</h3>
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
          <strong>#{l("field_#{field}")}:</strong>
          #{h(value)}
        </p>
      HTML
    end
  end
end