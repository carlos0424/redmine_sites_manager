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