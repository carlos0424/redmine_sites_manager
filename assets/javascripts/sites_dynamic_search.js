(function($) {
    'use strict';
  
    window.SitesManagerDynamic = {
      init: function() {
        this.initializeSearch();
        this.bindEvents();
      },
  
      bindEvents: function() {
        // Manejar cambio de tracker
        $(document).on('change', '#issue_tracker_id', () => {
          setTimeout(() => this.initializeSearch(), 500);
        });
  
        // Manejar el botón de limpiar
        $(document).on('click', '.sites-clear-btn', () => {
          const $searchField = $('#sites-search-field');
          $searchField.val('').trigger('input').focus();
          this.clearFields();
        });
  
        // Mostrar/ocultar botón de limpiar
        $(document).on('input', '#sites-search-field', function() {
          const $clearBtn = $('.sites-clear-btn');
          $clearBtn.toggle(Boolean($(this).val()));
        });
      },
  
      initializeSearch: function() {
        const $searchField = $('#sites-search-field');
        if (!$searchField.length) return;
  
        // Resetear autocompletado si existe
        if ($searchField.data('uiAutocomplete')) {
          $searchField.autocomplete('destroy');
        }
  
        // Inicializar autocompletado
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
                response(data);
              },
              error: (xhr, status, error) => {
                console.error('Error en búsqueda:', error);
                response([]);
              }
            });
          },
          minLength: 2,
          select: (event, ui) => {
            if (ui.item) {
              this.updateFields(ui.item.site_data);
              return false;
            }
          },
          response: (event, ui) => {
            // Manejar respuestas vacías
            if (!ui.content.length) {
              const noResult = { label: 'No se encontraron resultados' };
              ui.content.push(noResult);
            }
          }
        }).autocomplete('instance')._renderItem = (ul, item) => {
          if (!item.site_data) {
            return $('<li>')
              .append(`<div class="ui-menu-item-wrapper">${item.label}</div>`)
              .appendTo(ul);
          }
  
          return $('<li>')
            .append(`
              <div class="ui-menu-item-wrapper">
                <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                <br>
                <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
              </div>
            `)
            .appendTo(ul);
        };
  
        // Inicializar estado del botón de limpiar
        const $clearBtn = $('.sites-clear-btn');
        $clearBtn.toggle(Boolean($searchField.val()));
      },
  
      updateFields: function(siteData) {
        if (!siteData) return;
        
        const fieldMapping = {
          1: 's_id',
          5: 'nom_sitio',
          8: 'identificador',
          10: 'depto',
          2: 'municipio',
          3: 'direccion',
          6: 'jerarquia_definitiva',
          7: 'fijo_variable',
          9: 'coordinador',
          25: 'electrificadora',
          26: 'nic',
          32: 'zona_operativa'
        };
  
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
        const fieldIds = [1, 5, 8, 10, 2, 3, 6, 7, 9, 25, 26, 32];
        fieldIds.forEach(fieldId => {
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
  
      // Reinicializar cuando se carga contenido dinámicamente
      $(document).ajaxComplete(function(event, xhr, settings) {
        if (settings.url.includes('issues/new') || settings.url.includes('issues/edit')) {
          SitesManagerDynamic.init();
        }
      });
    });
  
  })(jQuery);