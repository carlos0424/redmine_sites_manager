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

    # Hook para agregar JS específico en ciertas páginas
    def view_layouts_base_body_bottom(context={})
      return unless should_include_js?(context)
      
      javascript_tag <<-JS
        $(function() {
          console.log("Inicializando búsqueda de sitios");

          window.sitesManagerSettings = {
            searchUrl: '#{sites_search_url}',
            fieldMapping: #{get_field_mapping.to_json}
          };

          // Inicialización de la búsqueda de sitios al cargar la página
          initSiteSearch();

          // Manejar cambio de tracker
          $(document).on('change', '#issue_tracker_id', function() {
            console.log("Cambio de tracker detectado. Reinicializando búsqueda.");
            $('#sites-search-field').autocomplete('destroy'); // Destruir autocompletado previo
            initSiteSearch(); // Re-inicializar búsqueda
          });
        });

        function initSiteSearch() {
          console.log("Ejecutando initSiteSearch");
          const $searchField = $('#sites-search-field');

          if (!$searchField.length) {
            console.log("Campo de búsqueda no encontrado");
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
          
          // Inicialización terminada
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

    def should_include_assets?(context)
      return false unless context[:controller]
      [IssuesController, SitesController].any? { |klass| context[:controller].is_a?(klass) }
    end

    def sites_search_url
      url_for(
        controller: 'sites',
        action: 'search',
        format: 'json',
        only_path: true
      )
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
  end
end
