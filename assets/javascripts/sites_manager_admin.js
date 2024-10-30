(function($) {
  'use strict';

  // Configuración global
  window.SitesManager = {
    config: {
      searchMinChars: 2,
      maxResults: 10,
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
        'nic': 26,
        'zona_operativa': 32
      }
    },

    init: function() {
      this.initializeSearchField();
      this.initializeAutocomplete();
      this.bindTrackerChangeEvent();
    },

    initializeSearchField: function() {
      const searchField = $('#sites-search-field');
      if (!searchField.length) return;

      searchField.attr('placeholder', SitesManager.translations?.placeholder);

      const clearBtn = $('.sites-clear-btn');
      if (clearBtn.length) {
        searchField.on('input', function() {
          clearBtn.toggle(Boolean($(this).val()));
        });

        clearBtn.on('click', function() {
          searchField.val('').trigger('input').focus();
          SitesManager.clearCustomFields();
        });

        clearBtn.toggle(Boolean(searchField.val()));
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

    bindTrackerChangeEvent: function() {
      // Detectar cambio de tracker y reinicializar el campo de búsqueda
      $('#issue_tracker_id').on('change', function() {
        SitesManager.initializeAutocomplete();
      });
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
      Object.entries(this.config.customFieldsMapping).forEach(([field, fieldId]) => {
        const element = $(`#issue_custom_field_values_${fieldId}`);
        if (element.length) {
          element.val('').trigger('change');
        }
      });
    }
  };

  // Inicializar cuando el documento está listo
  $(document).ready(function() {
    SitesManager.init();
  });

})(jQuery);
