(function($) {
  'use strict';

  // Configuración global
  window.SitesManager = {
    config: {
      searchMinChars: 2,
      maxResults: 10,
      createdStatusId: '1', // ID del estado "Creado"
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
        'nic': 26,
        'zona_operativa': 32
      }
    },

    init: function() {
      if (this.shouldInitialize()) {
        this.initializeSearchField();
        this.initializeAutocomplete();
        this.initializeStatusHandler();
        this.updateSearchVisibility();
      }
    },

    shouldInitialize: function() {
      // Solo inicializar si estamos en el formulario de issue
      return $('#issue-form').length > 0;
    },

    initializeSearchField: function() {
      const searchField = $('#sites-search-field');
      if (!searchField.length) return;

      searchField.attr('placeholder', SitesManager.translations?.searchPlaceholder);

      const $clearBtn = $('.sites-clear-btn');
      if ($clearBtn.length) {
        searchField.on('input', function() {
          $clearBtn.toggle(Boolean($(this).val()));
        });

        $clearBtn.on('click', function() {
          searchField.val('').trigger('input').focus();
          SitesManager.clearCustomFields();
        });

        $clearBtn.toggle(Boolean(searchField.val()));
      }
    },

    initializeStatusHandler: function() {
      $('#issue_status_id').on('change', () => {
        this.updateSearchVisibility();
      });
    },

    updateSearchVisibility: function() {
      const $container = $('.sites-search-container');
      if (!$container.length) return;

      const isNewIssue = !$('#issue_id').val();
      const currentStatus = $('#issue_status_id').val();
      const isCreatedStatus = currentStatus === this.config.createdStatusId;

      // Mostrar solo si:
      // 1. Es un nuevo issue (formulario de creación)
      // O
      // 2. Está en estado "Creado" (ID 1)
      const shouldShow = isNewIssue || isCreatedStatus;

      if (shouldShow) {
        $container.show();
      } else {
        $container.hide();
        // Opcionalmente, limpiar los campos cuando se oculta
        if (!isNewIssue) {
          this.clearCustomFields();
        }
      }
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
            },
            error: function() {
              response([]);
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
      }).autocomplete("instance")._renderItem = function(ul, item) {
        return $("<li>")
          .append(`<div class="autocomplete-item">
                    <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
                    <br>
                    <small>${item.site_data.municipio || ''} ${item.site_data.direccion ? '- ' + item.site_data.direccion : ''}</small>
                  </div>`)
          .appendTo(ul);
      };
    },

    updateCustomFields: function(siteData) {
      Object.entries(this.config.customFieldsMapping).forEach(([field, fieldId]) => {
        const element = $(`#issue_custom_field_values_${fieldId}`);
        if (element.length && siteData[field]) {
          element.val(siteData[field]).trigger('change');
        }
      });
    },

    clearCustomFields: function() {
      Object.entries(this.config.customFieldsMapping).forEach(([field, fieldId]) => {
        const element = $(`#issue_custom_field_values_${fieldId}`);
        if (element.length) {
          element.val('').trigger('change');
        }
      });
    }
  };

  // Inicialización cuando el documento está listo
  $(document).ready(function() {
    SitesManager.init();
  });

})(jQuery);

function initializeSitesSearch() {
  const $searchField = $('#sites-search-field');
  const $clearBtn = $('.sites-clear-btn');
  
  if (!$searchField.length) return;

  // Destruir instancia existente si existe
  if ($searchField.data('uiAutocomplete')) {
    $searchField.autocomplete('destroy');
  }

  // Inicializar autocompletado
  $searchField.autocomplete({
    source: function(request, response) {
      $.ajax({
        url: window.sitesManagerSettings.searchUrl,
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
        updateFields(ui.item.site_data);
      }
      return false;
    }
  }).autocomplete('instance')._renderItem = function(ul, item) {
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

  // Configurar botón de limpiar
  $clearBtn.off('click').on('click', function() {
    $searchField.val('').trigger('input').focus();
    clearFields();
  });

  // Manejar visibilidad del botón de limpiar
  $searchField.off('input').on('input', function() {
    $clearBtn.toggle(Boolean($(this).val()));
  }).trigger('input');
}

function updateFields(siteData) {
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
}

function clearFields() {
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