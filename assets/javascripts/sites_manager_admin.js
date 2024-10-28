(function($) {
  'use strict';

  // Configuración global
  window.SitesManager = {
    config: {
      searchMinChars: 2,
      maxResults: 10,
      allowedStatuses: ['1'], // IDs de estados permitidos (1 = Nuevo)
      customFieldsMapping: {
        's_id': 1,
        'nom_sitio': 5,
        'identificador': 7,
        'depto': 2,
        'municipio': 3,
        'direccion': 6,
        'jerarquia_definitiva': 8,
        'fijo_variable': 10,
        'coordinador': 9,
        'electrificadora': 25,
        'nic': 26
      }
    },

    init: function() {
      this.initializeSearchField();
      this.initializeAutocomplete();
      this.initializeStatusHandler();
      this.updateSearchVisibility(); // Verificar visibilidad inicial
    },

    initializeSearchField: function() {
      const searchField = $('#sites-search-field');
      if (!searchField.length) return;

      // Establecer placeholder desde las traducciones
      searchField.attr('placeholder', SitesManager.translations?.searchPlaceholder);

      // Inicializar el botón de limpiar
      const $clearBtn = $('.sites-clear-btn');
      if ($clearBtn.length) {
        searchField.on('input', function() {
          $clearBtn.toggle(Boolean($(this).val()));
        });

        $clearBtn.on('click', function() {
          searchField.val('').trigger('input').focus();
          SitesManager.clearCustomFields();
        });

        // Estado inicial del botón de limpiar
        $clearBtn.toggle(Boolean(searchField.val()));
      }
    },

    initializeAutocomplete: function() {
      const searchField = $('#sites-search-field');
      if (!searchField.length) return;

      searchField.autocomplete({
        source: function(request, response) {
          if (request.term.length < SitesManager.config.searchMinChars) return;

          $.ajax({
            url: '/sites/search',
            method: 'GET',
            data: { term: request.term },
            success: function(data) {
              response(data.slice(0, SitesManager.config.maxResults).map(site => ({
                label: `${site.s_id} - ${site.nom_sitio}`,
                value: `${site.s_id} - ${site.nom_sitio}`,
                site_data: site
              })));
            },
            error: function() {
              response([]);
            }
          });
        },
        minLength: SitesManager.config.searchMinChars,
        select: function(event, ui) {
          if (ui.item) {
            SitesManager.updateCustomFields(ui.item.site_data);
          }
          return false;
        }
      }).autocomplete("instance")._renderItem = function(ul, item) {
        return $("<li>")
          .append(`<div class="autocomplete-item">
                    <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                    <br>
                    <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
                  </div>`)
          .appendTo(ul);
      };
    },

    initializeStatusHandler: function() {
      const $statusSelect = $('#issue_status_id');
      if ($statusSelect.length) {
        $statusSelect.on('change', () => this.updateSearchVisibility());
        
        // Observar cambios en el formulario que podrían afectar la visibilidad
        const observer = new MutationObserver(() => this.updateSearchVisibility());
        observer.observe($statusSelect[0], { 
          attributes: true, 
          attributeFilter: ['value'] 
        });
      }
    },

    updateSearchVisibility: function() {
      const $container = $('.sites-search-container');
      if (!$container.length) return;

      const $statusSelect = $('#issue_status_id');
      const issueId = $('#issue_id').val();
      
      // Mostrar el campo solo si:
      // 1. Es un nuevo issue (no tiene ID) o
      // 2. El estado actual está en la lista de estados permitidos
      const shouldShow = !issueId || 
                        this.config.allowedStatuses.includes($statusSelect.val());

      $container.toggle(shouldShow);

      // Si se está ocultando, limpiar los campos
      if (!shouldShow) {
        this.clearCustomFields();
      }
    },

    updateCustomFields: function(siteData) {
      Object.entries(this.config.customFieldsMapping).forEach(([field, fieldId]) => {
        const element = $(`#issue_custom_field_values_${fieldId}`);
        if (element.length && siteData[field]) {
          element.val(siteData[field]).trigger('change');
        }
      });
    },

    clearCustomFields: function() {
      Object.values(this.config.customFieldsMapping).forEach(fieldId => {
        const element = $(`#issue_custom_field_values_${fieldId}`);
        if (element.length) {
          element.val('').trigger('change');
        }
      });
    }
  };

  // Inicialización cuando el documento está listo
  $(document).ready(function() {
    if ($('#issue-form').length) {
      SitesManager.init();
    }
  });

})(jQuery);