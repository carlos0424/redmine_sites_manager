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
      return '' unless show_site_search?(context[:issue])
      
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
        console.log("Inicializando búsqueda de sitios en el hook");
  
        window.sitesManagerSettings = {
          searchUrl: '#{sites_search_url}',
          customFieldMappings: #{get_custom_field_mappings.to_json},
          translations: #{get_translations.to_json},
          fieldMapping: #{get_field_mapping.to_json}
        };
  
        // Inicializar la búsqueda al cargar la página si el campo está presente
        if ($('#sites-search-field').length) {
          initializeSitesSearch();
        }
  
        // Re-inicialización en cambio de tracker
        $(document).on('change', '#issue_tracker_id', function() {
          console.log("Cambio de tracker detectado. Reinicializando búsqueda.");
          
          // Destruye el autocompletado previo y verifica el estado antes de re-inicializar
          $('#sites-search-field').autocomplete('destroy');
          console.log("Autocompletado destruido. Intentando re-inicializar.");
  
          // Esperar un momento para asegurar que el campo esté listo para re-inicializar
          setTimeout(function() {
            initializeSitesSearch();
            console.log("initializeSitesSearch invocado tras cambio de tracker.");
          }, 100); // Espera 100 ms para asegurar que el DOM esté actualizado
        });
      });
  
      function initializeSitesSearch() {
        console.log("Ejecutando initializeSitesSearch");
  
        const $searchField = $('#sites-search-field');
        if (!$searchField.length) {
          console.log("Campo de búsqueda no encontrado en initializeSitesSearch");
          return;
        }
  
        // Configuración de autocompletado
        $searchField.autocomplete({
          source: function(request, response) {
            $.ajax({
              url: window.sitesManagerSettings.searchUrl,
              data: { term: request.term },
              success: function(data) {
                console.log("Datos recibidos:", data);
                response(data);
              },
              error: function() {
                console.log("Error al obtener datos de sitios");
                response([]);
              }
            });
          },
          minLength: 2,
          select: function(event, ui) {
            console.log("Sitio seleccionado:", ui.item);
            if (ui.item && ui.item.site_data) {
              updateFields(ui.item.site_data);
            }
            return false;
          }
        });
  
        // Configurar el botón de limpiar búsqueda
        const $clearBtn = $('.sites-clear-btn');
        $searchField.on('input', function() {
          $clearBtn.toggle(Boolean($(this).val()));
        });
        
        $clearBtn.on('click', function() {
          console.log("Limpieza de campo de búsqueda");
          $searchField.val('').trigger('input').focus();
          clearFields();
        });
        
        console.log("Búsqueda de sitios inicializada");
      }
  
      function updateFields(siteData) {
        if (!siteData) return;
        console.log("Actualizando campos con los datos del sitio:", siteData);
        
        const fieldMapping = window.sitesManagerSettings.fieldMapping;
        Object.entries(fieldMapping).forEach(([fieldId, field]) => {
          if (!siteData[field]) return;
          const element = $(`#issue_custom_field_values_${fieldId}`);
          if (element.length) {
            element.val(siteData[field]).trigger('change');
          }
        });
      }
  
      function clearFields() {
        console.log("Limpiando campos personalizados");
        const fieldMapping = window.sitesManagerSettings.fieldMapping;
        Object.values(fieldMapping).forEach(fieldId => {
          const element = $(`#issue_custom_field_values_${fieldId}`);
          if (element.length) {
            element.val('').trigger('change');
          }
        });
      }
    JS
  end
  
  

    private

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
      
      # Solo incluir JS en las acciones relevantes del controlador de issues
      allowed_actions = ['new', 'create', 'edit', 'update']
      allowed_actions.include?(context[:controller].action_name)
    end
  end
  
  # Registrar los hooks para assets
  class SitesManagerHooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head,
              partial: 'sites_manager/html_head'
  end
end