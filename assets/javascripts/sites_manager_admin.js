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
          'nic': 26
        }
      },
  
      init: function() {
        this.initializeSearchField();
        this.initializeAutocomplete();
      },
  
      initializeSearchField: function() {
        const searchField = $('#sites-search-field');
        if (!searchField.length) return;
  
        // Establecer placeholder desde las traducciones
        searchField.attr('placeholder', SitesManager.translations.searchPlaceholder);
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
        });
      },
  
      updateCustomFields: function(siteData) {
        Object.entries(this.config.customFieldsMapping).forEach(([field, fieldId]) => {
          const element = $(`#issue_custom_field_values_${fieldId}`);
          if (element.length && siteData[field]) {
            element.val(siteData[field]).trigger('change');
          }
        });
      }
    };
  
    // Inicialización cuando el documento está listo
    $(document).ready(function() {
      SitesManager.init();
    });
  
  })(jQuery);