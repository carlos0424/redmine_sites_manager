(function($) {
    'use strict';
  
    window.SitesManagerDynamic = {
      init: function() {
        this.initializeSearch();
        this.bindEvents();
      },
  
      bindEvents: function() {
        $('#issue_tracker_id').on('change', () => {
          this.initializeSearch();
        });
      },
  
      initializeSearch: function() {
        const $searchField = $('#sites-search-field');
        if (!$searchField.length) return;
  
        if ($searchField.data('uiAutocomplete')) {
          $searchField.autocomplete('destroy');
        }
  
        $searchField.autocomplete({
          source: (request, response) => {
            $.ajax({
              url: '/sites/search',
              method: 'GET',
              data: { 
                term: request.term,
                authenticity_token: $('meta[name="csrf-token"]').attr('content')
              },
              success: (data) => {
                if (data.error) {
                  console.error('Error en búsqueda:', data.error);
                  // Intentar con la ruta alternativa si la primera falla
                  this.fallbackSearch(request.term, response);
                  return;
                }
                response(data);
              },
              error: (xhr, status, error) => {
                console.error('Error en la búsqueda:', error);
                // Intentar con la ruta alternativa
                this.fallbackSearch(request.term, response);
              }
            });
          },
          minLength: 2,
          select: (event, ui) => {
            if (ui.item) {
              this.updateFields(ui.item.site_data);
            }
            return false;
          }
        }).autocomplete('instance')._renderItem = (ul, item) => {
          return $('<li>')
            .append(`
              <div class="autocomplete-item">
                <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
              </div>
            `)
            .appendTo(ul);
        };
  
        const $clearBtn = $('.sites-clear-btn');
        $clearBtn.off('click').on('click', () => {
          $searchField.val('').trigger('input').focus();
          this.clearFields();
        });
  
        $searchField.off('input').on('input', function() {
          $clearBtn.toggle(Boolean($(this).val()));
        }).trigger('input');
      },
  
      fallbackSearch: function(term, response) {
        $.ajax({
          url: '/sites/autocomplete',
          method: 'GET',
          data: { 
            term: term,
            authenticity_token: $('meta[name="csrf-token"]').attr('content')
          },
          success: (data) => {
            response(data);
          },
          error: (xhr, status, error) => {
            console.error('Error en búsqueda alternativa:', error);
            response([]);
          }
        });
      },
  
      updateFields: function(siteData) {
        if (!siteData) return;
        
        const fieldMapping = window.sitesManagerSettings.fieldMapping;
        Object.entries(fieldMapping).forEach(([fieldId, field]) => {
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
        const fieldMapping = window.sitesManagerSettings.fieldMapping;
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
  
    $(document).ready(function() {
      SitesManagerDynamic.init();
    });
  
  })(jQuery);