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
          source: function(request, response) {
            $.ajax({
              url: '/sites/search',
              method: 'GET',
              data: { 
                term: request.term,
                authenticity_token: $('meta[name="csrf-token"]').attr('content')
              },
              success: function(data) {
                if (data.error) {
                  response([]);
                  console.error('Error en búsqueda:', data.error);
                  return;
                }
                response($.map(data, function(item) {
                  return {
                    label: item.label,
                    value: item.value,
                    site_data: item.site_data
                  };
                }));
              },
              error: function(xhr, status, error) {
                console.error('Error en la búsqueda:', error);
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
                <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
              </div>
            `)
            .appendTo(ul);
        };
  
        const $clearBtn = $('.sites-clear-btn');
        $clearBtn.off('click').on('click', function() {
          $searchField.val('').trigger('input').focus();
          SitesManagerDynamic.clearFields();
        });
  
        $searchField.off('input').on('input', function() {
          $clearBtn.toggle(Boolean($(this).val()));
        }).trigger('input');
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