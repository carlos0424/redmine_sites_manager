(function($) {
    'use strict';
  
    window.SitesManagerDynamic = {
      init: function() {
        this.bindTrackerChange();
        this.initializeSearch();
      },
  
      bindTrackerChange: function() {
        // Manejar cambios de tracker para reinicializar la búsqueda
        $('#issue_tracker_id').on('change', () => {
          this.initializeSearch();
        });
  
        // Manejar cambios por APIs externas
        $(document).on('change', '#issue_tracker_id', () => {
          this.initializeSearch();
        });
      },
  
      initializeSearch: function() {
        const $searchField = $('#sites-search-field');
        if (!$searchField.length) return;
  
        // Destruir instancia anterior de autocomplete si existe
        if ($searchField.data('uiAutocomplete')) {
          $searchField.autocomplete('destroy');
        }
  
        // Reinicializar autocomplete
        $searchField.autocomplete({
          source: function(request, response) {
            $.ajax({
              url: '/sites/search',
              method: 'GET',
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
            if (ui.item) {
              SitesManagerDynamic.updateFields(ui.item.site_data);
            }
            return false;
          }
        }).autocomplete('instance')._renderItem = function(ul, item) {
          return $('<li>')
            .append(`
              <div class="autocomplete-item">
                <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                <br>
                <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
              </div>
            `)
            .appendTo(ul);
        };
  
        // Manejar el botón de limpiar
        const $clearBtn = $('.sites-clear-btn');
        $clearBtn.off('click').on('click', function() {
          $searchField.val('').trigger('input').focus();
          SitesManagerDynamic.clearFields();
        });
  
        $searchField.off('input').on('input', function() {
          $clearBtn.toggle(Boolean($(this).val()));
        }).trigger('input');
  
        // Mostrar siempre el contenedor de búsqueda
        $('.sites-search-container').show();
      },
  
      updateFields: function(siteData) {
        const fieldMapping = {
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
        };
  
        Object.entries(fieldMapping).forEach(([field, fieldId]) => {
          if (!siteData[field]) return;
          
          const element = $(`#issue_custom_field_values_${fieldId}`);
          if (!element.length) return;
  
          element
            .val(siteData[field])
            .trigger('change')
            .removeClass('campo-variable campo-fijo');
  
          if (field === 'fijo_variable') {
            element.addClass(siteData[field].toLowerCase() === 'variable' ? 'campo-variable' : 'campo-fijo');
          }
        });
      },
  
      clearFields: function() {
        const fieldMapping = {
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
        };
  
        Object.values(fieldMapping).forEach(fieldId => {
          const element = $(`#issue_custom_field_values_${fieldId}`);
          if (element.length) {
            element
              .val('')
              .trigger('change')
              .removeClass('campo-variable campo-fijo');
          }
        });
      }
    };
  
    // Inicializar cuando el documento está listo
    $(document).ready(function() {
      SitesManagerDynamic.init();
  
      // Reinicializar cuando se carga un nuevo formulario dinámicamente
      $(document).on('ajax:complete', function() {
        SitesManagerDynamic.init();
      });
    });
  
  })(jQuery);