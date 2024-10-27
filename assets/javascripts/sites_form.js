$(function() {
  // Mapeo de campos del sitio a campos personalizados
  const fieldMapping = {
    1: 's_id',
    5: 'nom_sitio',
    8: 'identificador',
    10: 'depto',
    2: 'municipio',
    3: 'direccion',
    6: 'jerarquia_definitiva',
    7: 'fijo_variable',
    9: 'coordinador'
  };

  // Inicializar autocompletado
  $('#sites-search-field').autocomplete({
    source: function(request, response) {
      $.ajax({
        url: '/sites/search',
        dataType: 'json',
        data: { term: request.term },
        success: function(data) {
          response(data);
        }
      });
    },
    minLength: 2,
    select: function(event, ui) {
      // Llenar los campos personalizados con los datos del sitio
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
        <div>
          <strong>${item.site_data.s_id} - ${item.site_data.nom_sitio}</strong>
          <br>
          <small>${item.site_data.municipio} - ${item.site_data.direccion || ''}</small>
        </div>
      `)
      .appendTo(ul);
  };

  // Agregar botón para limpiar la búsqueda
  const $searchField = $('#sites-search-field');
  const $clearButton = $('<span>', {
    class: 'clear-site-search',
    html: '×',
    title: 'Limpiar selección'
  }).insertAfter($searchField);

  // Función para limpiar todos los campos
  function clearFields() {
    $searchField.val('');
    Object.keys(fieldMapping).forEach(customFieldId => {
      $(`#issue_custom_field_values_${customFieldId}`).val('').trigger('change');
    });
  }

  // Manejar clic en botón de limpiar
  $clearButton.on('click', clearFields);

  // Estilos para el autocompletado y el botón de limpiar
  $('<style>')
    .text(`
      .ui-autocomplete {
        max-height: 300px;
        overflow-y: auto;
        overflow-x: hidden;
        border: 1px solid #ccc;
        border-radius: 3px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .ui-autocomplete .ui-menu-item {
        padding: 5px 8px;
        border-bottom: 1px solid #eee;
      }
      .ui-autocomplete .ui-menu-item:last-child {
        border-bottom: none;
      }
      .ui-autocomplete .ui-menu-item div {
        padding: 3px 0;
      }
      .ui-autocomplete .ui-menu-item strong {
        color: #333;
      }
      .ui-autocomplete .ui-menu-item small {
        color: #666;
        font-size: 0.9em;
      }
      .clear-site-search {
        position: absolute;
        right: 10px;
        top: 50%;
        transform: translateY(-50%);
        cursor: pointer;
        color: #999;
        font-size: 18px;
        font-weight: bold;
        padding: 0 5px;
      }
      .clear-site-search:hover {
        color: #666;
      }
      .sites-search-container {
        position: relative;
      }
      .sites-autocomplete {
        width: 100%;
        padding: 6px 30px 6px 8px;
        border: 1px solid #ccc;
        border-radius: 3px;
      }
    `)
    .appendTo('head');
});