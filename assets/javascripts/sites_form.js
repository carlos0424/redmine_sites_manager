$(function() {
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
    26: 'nic'
  };

  $('#sites-search-field').autocomplete({
    source: function(request, response) {
      $.ajax({
        url: '/sites/search',
        type: 'GET',
        dataType: 'json',
        data: { 
          term: request.term,
          authenticity_token: $('meta[name="csrf-token"]').attr('content')
        },
        success: function(data) {
          response(data);
        }
      });
    },
    minLength: 2,
    select: function(event, ui) {
      Object.entries(fieldMapping).forEach(([customFieldId, siteField]) => {
        const value = ui.item.site_data[siteField];
        if (value) {
          $(`#issue_custom_field_values_${customFieldId}`).val(value).trigger('change');
        }
      });
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

  $('.select2').select2({
    width: '100%',
    placeholder: 'Seleccione un coordinador',
    allowClear: true
  });

  // Formatear automáticamente el S ID
  $('#flm_site_s_id').on('blur', function() {
    var value = $(this).val().trim().toUpperCase();
    if (value && !value.startsWith('S')) {
      value = 'S' + value;
    }
    $(this).val(value);
  });

  // Formatear automáticamente la jerarquía
  $('#flm_site_jerarquia_definitiva').on('blur', function() {
    var value = $(this).val().trim().toUpperCase();
    if (value && !value.startsWith('B_')) {
      value = 'B_' + value;
    }
    $(this).val(value);
  });
  

  // Agregar botón de limpiar
  const $searchContainer = $('#sites-search-field').parent();
  const $clearButton = $('<span>', {
    class: 'clear-site-search icon-close',
    title: 'Limpiar selección'
  }).appendTo($searchContainer);

  // Función para limpiar campos
  function clearFields() {
    $('#sites-search-field').val('');
    Object.keys(fieldMapping).forEach(customFieldId => {
      $(`#issue_custom_field_values_${customFieldId}`).val('').trigger('change');
    });
  }

  $clearButton.on('click', clearFields);
});

// assets/javascripts/sites_form.js
$(function() {
  function shouldEnableSiteSearch() {
    // Obtener el ID del estado actual
    var currentStatusId = $('#issue_status_id').val();
    var isNewRecord = !$('#issue_id').val(); // Si no hay ID, es nuevo
    
    // Lista de estados permitidos
    var allowedStatuses = ['1']; // IDs de estados como strings
    
    return isNewRecord || allowedStatuses.includes(currentStatusId);
  }

  function updateSiteSearchVisibility() {
    var $container = $('.sites-search-container');
    if (shouldEnableSiteSearch()) {
      $container.show();
    } else {
      $container.hide();
    }
  }

  // Actualizar visibilidad cuando cambie el estado
  $('#issue_status_id').on('change', updateSiteSearchVisibility);
  
  // Actualizar visibilidad inicial
  updateSiteSearchVisibility();
});