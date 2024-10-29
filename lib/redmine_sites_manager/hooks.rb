module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
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
          .ui-menu-item {
            padding: 5px 8px;
            cursor: pointer;
          }
          .ui-menu-item:hover {
            background: #f5f5f5;
          }
          .ui-menu-item strong {
            display: block;
            color: #333;
          }
          .ui-menu-item small {
            color: #666;
            font-size: 0.9em;
          }
        </style>
      CSS

      "#{stylesheet}\n#{javascript}\n#{styles}".html_safe
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

    def view_layouts_base_body_bottom(context={})
      return unless should_include_js?(context)
      
      javascript_tag <<-JS
        $(function() {
          window.sitesManagerSettings = {
            searchUrl: '#{sites_search_url}',
            fieldMapping: #{get_field_mapping.to_json}
          };

          function reinitializeSearch() {
            const $searchField = $('#sites-search-field');
            
            // Destruir instancia previa si existe
            if ($searchField.data('uiAutocomplete')) {
              $searchField.autocomplete('destroy');
            }

            if ($searchField.length) {
              // Configurar autocompletado
              $searchField.autocomplete({
                source: function(request, response) {
                  $.ajax({
                    url: window.sitesManagerSettings.searchUrl,
                    data: { 
                      term: request.term,
                      authenticity_token: $('meta[name="csrf-token"]').attr('content')
                    },
                    success: function(data) {
                      response(data);
                    },
                    error: function() {
                      response([]);
                    }
                  });
                },
                minLength: 2,
                select: function(event, ui) {
                  if (ui.item && ui.item.site_data) {
                    updateFields(ui.item.site_data);
                  }
                  return false;
                }
              }).autocomplete('instance')._renderItem = function(ul, item) {
                if (!item.site_data) {
                  return $('<li>')
                    .append($('<div>').text(item.label))
                    .appendTo(ul);
                }

                return $('<li>')
                  .append(`
                    <div class="ui-menu-item-wrapper">
                      <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                      <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
                    </div>
                  `)
                  .appendTo(ul);
              };

              // Configurar botón de limpiar
              const $clearBtn = $('.sites-clear-btn');
              
              $clearBtn.off('click').on('click', function() {
                $searchField.val('').trigger('input').focus();
                clearFields();
              });

              $searchField.off('input').on('input', function() {
                $clearBtn.toggle(Boolean($(this).val()));
              }).trigger('input');
            }
          }

          function updateFields(siteData) {
            if (!siteData) return;
            
            const fieldMapping = window.sitesManagerSettings.fieldMapping;
            Object.entries(fieldMapping).forEach(([fieldId, field]) => {
              if (!siteData[field]) return;
              
              const $element = $(`#issue_custom_field_values_${fieldId}`);
              if ($element.length) {
                $element
                  .val(siteData[field])
                  .trigger('change')
                  .removeClass('campo-variable campo-fijo');

                if (field === 'fijo_variable') {
                  $element.addClass(siteData[field].toLowerCase() === 'variable' ? 'campo-variable' : 'campo-fijo');
                }
              }
            });
          }

          function clearFields() {
            const fieldMapping = window.sitesManagerSettings.fieldMapping;
            Object.keys(fieldMapping).forEach(fieldId => {
              const $element = $(`#issue_custom_field_values_${fieldId}`);
              if ($element.length) {
                $element
                  .val('')
                  .trigger('change')
                  .removeClass('campo-variable campo-fijo');
              }
            });
          }

          // Inicialización inicial
          reinitializeSearch();

          // Reinicializar cuando cambia el tracker
          $('#issue_tracker_id').on('change', function() {
            setTimeout(reinitializeSearch, 100);
          });

          // Reinicializar después de cargas AJAX
          $(document).ajaxComplete(function(event, xhr, settings) {
            if (settings.url && (settings.url.includes('issues/new') || 
                               settings.url.includes('issues/edit'))) {
              setTimeout(reinitializeSearch, 100);
            }
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