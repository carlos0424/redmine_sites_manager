// assets/javascripts/sites_manager_admin.js
(function($) {
  'use strict';

  window.SitesManager = {
    config: {
      searchMinChars: 2,
      maxResults: 10,
      fieldMapping: {
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
      }
    },

    init: function() {
      console.log("Initializing SitesManager...");
      this.setupEventHandlers();
      this.initializeSearchField();
    },

    setupEventHandlers: function() {
      // Manejar cambios en el tracker
      $(document).on('change', '#issue_tracker_id', () => {
        console.log("Tracker changed");
        this.handleTrackerChange();
      });

      // Manejar actualizaciones dinámicas del formulario
      $(document).ajaxComplete((event, xhr, settings) => {
        if (settings.url && (settings.url.includes('issues/new') || settings.url.includes('issues/edit'))) {
          console.log("Form updated via AJAX");
          this.initializeSearchField();
        }
      });

      // Manejar el botón de limpiar
      $(document).on('click', '.sites-clear-btn', () => {
        console.log("Clear button clicked");
        this.clearSearch();
      });

      // Mostrar/ocultar botón de limpiar
      $(document).on('input', '#sites-search-field', function() {
        $('.sites-clear-btn').toggle(Boolean($(this).val()));
      });
    },

    handleTrackerChange: function() {
      console.log("Handling tracker change");
      // Esperar a que el DOM se actualice
      setTimeout(() => {
        this.clearSearch();
        this.destroyAutocomplete();
        this.initializeSearchField();
      }, 500);
    },

    initializeSearchField: function() {
      const searchField = $('#sites-search-field');
      if (!searchField.length) {
        console.log("Search field not found");
        return;
      }

      console.log("Initializing search field");
      this.initializeAutocomplete(searchField);
    },

    destroyAutocomplete: function() {
      const searchField = $('#sites-search-field');
      if (searchField.data('uiAutocomplete')) {
        console.log("Destroying existing autocomplete");
        searchField.autocomplete('destroy');
      }
    },

    initializeAutocomplete: function(searchField) {
      console.log("Setting up autocomplete");
      
      searchField.autocomplete({
        source: (request, response) => {
          if (request.term.length < this.config.searchMinChars) {
            return;
          }

          $.ajax({
            url: '/sites/search',
            method: 'GET',
            data: {
              term: request.term,
              authenticity_token: $('meta[name="csrf-token"]').attr('content')
            },
            success: (data) => {
              console.log("Search results received:", data.length);
              response(this.formatAutocompleteData(data));
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
            console.log("Item selected:", ui.item.site_data.s_id);
            this.updateCustomFields(ui.item.site_data);
            return false;
          }
        },
        response: (event, ui) => {
          if (!ui.content.length) {
            ui.content.push({ 
              label: 'No se encontraron resultados',
              value: '',
              site_data: null
            });
          }
        }
      }).autocomplete('instance')._renderItem = (ul, item) => {
        return this.renderAutocompleteItem(ul, item);
      };

      // Configurar estado inicial del botón de limpiar
      $('.sites-clear-btn').toggle(Boolean(searchField.val()));
    },

    formatAutocompleteData: function(data) {
      return data.slice(0, this.config.maxResults).map(site => ({
        label: `${site.s_id} - ${site.nom_sitio}`,
        value: `${site.s_id} - ${site.nom_sitio}`,
        site_data: site
      }));
    },

    renderAutocompleteItem: function(ul, item) {
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
            <small>
              ${item.site_data.municipio || ''} 
              ${item.site_data.direccion ? ` - ${item.site_data.direccion}` : ''}
            </small>
          </div>
        `)
        .appendTo(ul);
    },

    updateCustomFields: function(siteData) {
      console.log("Updating custom fields");
      Object.entries(this.config.fieldMapping).forEach(([fieldId, field]) => {
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

    clearSearch: function() {
      console.log("Clearing search");
      const searchField = $('#sites-search-field');
      searchField.val('').trigger('input');
      this.clearCustomFields();
    },

    clearCustomFields: function() {
      console.log("Clearing custom fields");
      Object.entries(this.config.fieldMapping).forEach(([fieldId, field]) => {
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

  // Inicialización
  $(document).ready(function() {
    SitesManager.init();
  });

})(jQuery);