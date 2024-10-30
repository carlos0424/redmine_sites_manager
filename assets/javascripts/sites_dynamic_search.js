// assets/javascripts/sites_dynamic_search.js
(function($) {
  'use strict';

  var SitesManager = {
    init: function() {
      this.searchField = $('#sites-search-field');
      if (!this.searchField.length) return;

      this.clearBtn = $('.sites-clear-btn');
      this.setupAutocomplete();
      this.setupClearButton();
      this.handleVisibility();
    },

    setupAutocomplete: function() {
      var self = this;
      var fieldMapping = JSON.parse(this.searchField.data('mapping'));

      this.searchField.autocomplete({
        source: function(request, response) {
          $.ajax({
            url: '/sites/search',
            method: 'GET',
            data: { term: request.term },
            success: function(data) {
              response(data);
            },
            error: function(xhr, status, error) {
              console.error('Error en búsqueda:', error);
              response([]);
            }
          });
        },
        minLength: 2,
        select: function(event, ui) {
          if (ui.item) {
            self.updateCustomFields(ui.item.site_data, fieldMapping);
            return false;
          }
        }
      }).autocomplete('instance')._renderItem = function(ul, item) {
        return $('<li>')
          .append(`
            <div class="ui-menu-item-wrapper">
              <div class="site-result">
                <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                <small>
                  ${item.site_data.municipio || ''}
                  ${item.site_data.direccion ? ` - ${item.site_data.direccion}` : ''}
                </small>
              </div>
            </div>
          `)
          .appendTo(ul);
      };
    },

    setupClearButton: function() {
      var self = this;
      
      this.clearBtn.on('click', function() {
        self.searchField.val('').trigger('input');
        self.clearCustomFields();
      });

      this.searchField.on('input', function() {
        self.clearBtn.toggle(Boolean($(this).val()));
      }).trigger('input');
    },

    handleVisibility: function() {
      var container = $('.sites-search-container');
      var currentStatus = $('#issue_status_id').val();
      var isNewIssue = !$('#issue_id').val();

      // Mostrar solo en nuevo issue o estados permitidos
      var shouldShow = isNewIssue || currentStatus === '1';
      container.toggle(shouldShow);

      // Actualizar visibilidad cuando cambie el estado
      $('#issue_status_id').on('change', function() {
        container.toggle(isNewIssue || $(this).val() === '1');
      });
    },

    updateCustomFields: function(siteData, fieldMapping) {
      Object.entries(fieldMapping).forEach(function([siteField, customFieldId]) {
        if (!siteData[siteField] || !customFieldId) return;
        
        var field = $(`#issue_custom_field_values_${customFieldId}`);
        if (!field.length) return;

        field.val(siteData[siteField]).trigger('change');
        
        // Manejar estilos especiales para fijo/variable
        if (siteField === 'fijo_variable') {
          field
            .removeClass('campo-variable campo-fijo')
            .addClass(siteData[siteField].toLowerCase() === 'variable' ? 'campo-variable' : 'campo-fijo');
        }
      });
    },

    clearCustomFields: function() {
      var fieldMapping = JSON.parse(this.searchField.data('mapping'));
      Object.values(fieldMapping).forEach(function(customFieldId) {
        if (!customFieldId) return;
        
        var field = $(`#issue_custom_field_values_${customFieldId}`);
        if (field.length) {
          field
            .val('')
            .trigger('change')
            .removeClass('campo-variable campo-fijo');
        }
      });
    }
  };

  // Inicializar cuando el documento esté listo
  $(document).ready(function() {
    SitesManager.init();
  });

  // Reinicializar cuando se cargue contenido dinámico
  $(document).ajaxComplete(function(event, xhr, settings) {
    if (settings.url.includes('issues/new') || settings.url.includes('issues/edit')) {
      SitesManager.init();
    }
  });

})(jQuery);