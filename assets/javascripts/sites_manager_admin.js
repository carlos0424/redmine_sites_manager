// assets/javascripts/sites_manager_admin.js
(function($) {
  'use strict';

  window.SitesManager = {
    config: {
      searchMinChars: 2,
      maxResults: 10,
      // Mapeo actualizado de campos personalizados
      fieldMapping: {
        's_id': '1',
        'nom_sitio': '5',
        'identificador': '7',
        'depto': '2',
        'municipio': '3',
        'direccion': '6',
        'jerarquia_definitiva': '8',
        'fijo_variable': '10',
        'coordinador': '9',
        'electrificadora': '25',
        'nic': '26',
        'zona_operativa': '32'
      }
    },

    init: function() {
      console.log("Initializing SitesManager...");
      this.setupEventHandlers();
      this.initializeSearchField();
    },

    setupEventHandlers: function() {
      $(document).on('change', '#issue_tracker_id', () => {
        console.log("Tracker changed");
        this.handleTrackerChange();
      });

      $(document).on('click', '.sites-clear-btn', () => {
        console.log("Clear button clicked");
        this.clearSearch();
      });

      $(document).on('input', '#sites-search-field', function() {
        $('.sites-clear-btn').toggle(Boolean($(this).val()));
      });
    },

    handleTrackerChange: function() {
      setTimeout(() => {
        this.clearSearch();
        this.destroyAutocomplete();
        this.initializeSearchField();
      }, 500);
    },

    initializeSearchField: function() {
      const searchField = $('#sites-search-field');
      if (!searchField.length) return;

      if (searchField.data('uiAutocomplete')) {
        searchField.autocomplete('destroy');
      }

      searchField.autocomplete({
        source: (request, response) => {
          if (request.term.length < this.config.searchMinChars) return;

          $.ajax({
            url: '/sites/search',
            method: 'GET',
            data: { 
              term: request.term,
              authenticity_token: $('meta[name="csrf-token"]').attr('content')
            },
            success: (data) => {
              console.log("Search results:", data);
              response(data);
            },
            error: (xhr, status, error) => {
              console.error("Search error:", error);
              response([]);
            }
          });
        },
        minLength: this.config.searchMinChars,
        select: (event, ui) => {
          if (ui.item && ui.item.site_data) {
            console.log("Selected site data:", ui.item.site_data);
            this.updateCustomFields(ui.item.site_data);
            return false;
          }
        }
      }).autocomplete('instance')._renderItem = (ul, item) => {
        if (!item.site_data) {
          return $('<li>')
            .append(`<div class="ui-menu-item-wrapper">No se encontraron resultados</div>`)
            .appendTo(ul);
        }

        return $('<li>')
          .append(`
            <div class="ui-menu-item-wrapper">
              <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
              <br>
              <small>
                ${item.site_data.municipio} 
                ${item.site_data.direccion ? ` - ${item.site_data.direccion}` : ''}
              </small>
            </div>
          `)
          .appendTo(ul);
      };
    },

    updateCustomFields: function(siteData) {
      console.log("Updating custom fields with:", siteData);
      
      Object.entries(this.config.fieldMapping).forEach(([field, customFieldId]) => {
        const value = siteData[field];
        if (typeof value === 'undefined') return;

        const elementId = `issue_custom_field_values_${customFieldId}`;
        const element = $(`#${elementId}`);
        
        if (element.length) {
          console.log(`Updating field ${elementId} with value:`, value);
          element.val(value).trigger('change');

          if (field === 'fijo_variable') {
            element
              .removeClass('campo-variable campo-fijo')
              .addClass(value.toLowerCase() === 'variable' ? 'campo-variable' : 'campo-fijo');
          }
        } else {
          console.warn(`Element not found: ${elementId}`);
        }
      });
    },

    clearSearch: function() {
      const searchField = $('#sites-search-field');
      searchField.val('').trigger('input');
      this.clearCustomFields();
    },

    clearCustomFields: function() {
      Object.values(this.config.fieldMapping).forEach(customFieldId => {
        const element = $(`#issue_custom_field_values_${customFieldId}`);
        if (element.length) {
          element
            .val('')
            .trigger('change')
            .removeClass('campo-variable campo-fijo');
        }
      });
    },

    destroyAutocomplete: function() {
      const searchField = $('#sites-search-field');
      if (searchField.data('uiAutocomplete')) {
        searchField.autocomplete('destroy');
      }
    }
  };

  $(document).ready(function() {
    SitesManager.init();
  });

})(jQuery);