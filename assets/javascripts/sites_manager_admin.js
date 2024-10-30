// assets/javascripts/sites_manager_admin.js
(function($) {
  'use strict';

  window.SitesManager = {
    config: {
      searchMinChars: 2,
      maxResults: 10,
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
      this.setupAjaxIndicator();
    },

    setupEventHandlers: function() {
      // Manejar cambio de tracker
      $(document).on('change', '#issue_tracker_id', () => {
        console.log("Tracker changed");
        this.handleTrackerChange();
      });

      // Manejar botón de limpiar
      $(document).on('click', '.sites-clear-btn', () => {
        console.log("Clear button clicked");
        this.clearSearch();
      });

      // Manejar entrada de búsqueda
      $(document).on('input', '#sites-search-field', function() {
        const hasValue = Boolean($(this).val());
        $('.sites-clear-btn').toggle(hasValue);
        $(this).toggleClass('has-value', hasValue);
      });

      // Manejar actualizaciones dinámicas
      $(document).ajaxComplete((event, xhr, settings) => {
        if (settings.url && (settings.url.includes('issues/new') || settings.url.includes('issues/edit'))) {
          console.log("Form updated via AJAX");
          this.initializeSearchField();
        }
      });
    },

    setupAjaxIndicator: function() {
      $(document).ajaxStart(() => {
        $('#sites-search-field').addClass('loading');
      }).ajaxStop(() => {
        $('#sites-search-field').removeClass('loading');
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

      this.destroyAutocomplete();

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
              response(this.formatSearchResults(data));
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
        },
        focus: function(event, ui) {
          event.preventDefault();
        }
      }).autocomplete('instance')._renderItem = (ul, item) => {
        return this.renderSearchResult(ul, item);
      };

      // Configurar estado inicial del botón de limpiar
      $('.sites-clear-btn').toggle(Boolean(searchField.val()));
    },

    formatSearchResults: function(data) {
      if (!data || !data.length) {
        return [{
          label: 'No se encontraron resultados',
          value: '',
          site_data: null
        }];
      }

      return data.slice(0, this.config.maxResults);
    },

    renderSearchResult: function(ul, item) {
      if (!item.site_data) {
        return $('<li>')
          .append(`<div class="ui-menu-item-wrapper no-results">No se encontraron resultados</div>`)
          .appendTo(ul);
      }

      const siteInfo = `
        <div class="ui-menu-item-wrapper site-result">
          <div class="site-main-info">
            <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
          </div>
          <div class="site-details">
            <span class="municipio">
              <i class="icon icon-location"></i>${item.site_data.municipio || ''}
            </span>
            <span class="identificador">
              <i class="icon icon-location"></i>${item.site_data.identificador || ''}
            </span>
            <span class="fijo_variable">
              <i class="icon icon-user"></i>${item.site_data.fijo_variable || ''}
            </span>
          </div>
        </div>
      `;

      return $('<li>')
        .append(siteInfo)
        .appendTo(ul);
    },

    updateCustomFields: function(siteData) {
      console.log("Updating custom fields with:", siteData);
      
      Object.entries(this.config.fieldMapping).forEach(([field, customFieldId]) => {
        const value = siteData[field];
        if (typeof value === 'undefined' || value === null) return;

        const elementId = `issue_custom_field_values_${customFieldId}`;
        const element = $(`#${elementId}`);
        
        if (element.length) {
          console.log(`Updating field ${elementId} with value:`, value);
          
          // Aplicar el valor y disparar eventos
          element
            .val(value)
            .trigger('change')
            .trigger('blur');


          // Añadir clase de campo actualizado
          element
            .addClass('field-updated')
            .delay(1000)
            .queue(function(next) {
              $(this).removeClass('field-updated');
              next();
            });
        } else {
          console.warn(`Element not found: ${elementId}`);
        }
      });

      // Mostrar notificación de actualización
      this.showUpdateNotification();
    },

    showUpdateNotification: function() {
      const notification = $('<div class="flash notice" style="display:none">')
        .text('Campos actualizados correctamente')
        .insertBefore('.sites-search-container');

      notification
        .slideDown()
        .delay(3000)
        .slideUp(function() {
          $(this).remove();
        });
    },

    clearSearch: function() {
      const searchField = $('#sites-search-field');
      searchField
        .val('')
        .trigger('input')
        .removeClass('has-value loading');
      this.clearCustomFields();
    },

    clearCustomFields: function() {
      Object.values(this.config.fieldMapping).forEach(customFieldId => {
        const element = $(`#issue_custom_field_values_${customFieldId}`);
        if (element.length) {
          element
            .val('')
            .trigger('change')
            .removeClass('campo-variable campo-fijo field-updated');
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