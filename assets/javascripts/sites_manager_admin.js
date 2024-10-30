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
      this.setupEventHandlers();
      this.initializeSearchField();
      this.setupAjaxIndicator();
    },

    setupEventHandlers: function() {
      $(document)
        .on('change', '#issue_tracker_id', () => this.handleTrackerChange())
        .on('click', '.sites-clear-btn', () => this.clearSearch())
        .on('input', '#sites-search-field', function() {
          $('.sites-clear-btn').toggle(Boolean($(this).val()));
          $(this).toggleClass('has-value', Boolean($(this).val()));
        })
        .ajaxComplete((event, xhr, settings) => {
          if (settings.url?.includes('issues/new') || settings.url?.includes('issues/edit')) {
            this.initializeSearchField();
          }
        });
    },

    setupAjaxIndicator: function() {
      $(document)
        .ajaxStart(() => $('#sites-search-field').addClass('loading'))
        .ajaxStop(() => $('#sites-search-field').removeClass('loading'));
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
        source: this.handleSearch.bind(this),
        minLength: this.config.searchMinChars,
        select: (event, ui) => {
          if (ui.item?.site_data) {
            this.updateCustomFields(ui.item.site_data);
            searchField.val(`${ui.item.site_data.s_id} - ${ui.item.site_data.nom_sitio}`);
            return false;
          }
        },
        focus: (event) => event.preventDefault()
      }).autocomplete('instance')._renderItem = (ul, item) => this.renderSearchResult(ul, item);

      $('.sites-clear-btn').toggle(Boolean(searchField.val()));
    },

    handleSearch: function(request, response) {
      if (request.term.length < this.config.searchMinChars) return;

      $.ajax({
        url: '/sites/search',
        method: 'GET',
        data: { 
          term: request.term,
          authenticity_token: $('meta[name="csrf-token"]').attr('content')
        },
        success: (data) => response(this.formatSearchResults(data)),
        error: () => response([])
      });
    },

    formatSearchResults: function(data) {
      if (!data?.length) {
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

      const details = [
        item.site_data.municipio,
        item.site_data.identificador,
        item.site_data.zona_operativa,
        item.site_data.fijo_variable
      ].filter(Boolean).join(' | ');

      const siteInfo = `
        <div class="ui-menu-item-wrapper site-result">
          <div class="site-main-info">
            <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
          </div>
          <div class="site-details">${details}</div>
        </div>
      `;

      return $('<li>').append(siteInfo).appendTo(ul);
    },

    updateCustomFields: function(siteData) {
      Object.entries(this.config.fieldMapping).forEach(([field, customFieldId]) => {
        const value = siteData[field];
        if (value == null) return;

        const element = $(`#issue_custom_field_values_${customFieldId}`);
        if (!element.length) return;

        element
          .val(value)
          .trigger('change')
          .trigger('blur')
          .addClass('field-updated')
          .delay(1000)
          .queue(function(next) {
            $(this).removeClass('field-updated');
            next();
          });
      });

      this.showUpdateNotification();
    },

    showUpdateNotification: function() {
      $('<div class="flash notice" style="display:none">')
        .text('Campos actualizados correctamente')
        .insertBefore('.sites-search-container')
        .slideDown()
        .delay(3000)
        .slideUp(function() {
          $(this).remove();
        });
    },

    clearSearch: function() {
      $('#sites-search-field')
        .val('')
        .trigger('input')
        .removeClass('has-value loading');
      this.clearCustomFields();
    },

    clearCustomFields: function() {
      Object.values(this.config.fieldMapping).forEach(customFieldId => {
        $(`#issue_custom_field_values_${customFieldId}`)
          .val('')
          .trigger('change')
          .removeClass('field-updated');
      });
    },

    destroyAutocomplete: function() {
      const searchField = $('#sites-search-field');
      if (searchField.data('uiAutocomplete')) {
        searchField.autocomplete('destroy');
      }
    }
  };

  $(document).ready(() => SitesManager.init());

})(jQuery);