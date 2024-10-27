// assets/javascripts/sites_form.js
$(function() {
    // Formatear S_ID
    $('#flm_site_s_id').on('blur', function() {
      var value = $(this).val().trim().toUpperCase();
      if (value && !value.startsWith('S')) {
        value = 'S' + value;
      }
      $(this).val(value);
    });
  
    // Formatear jerarquía
    $('#flm_site_jerarquia_definitiva').on('blur', function() {
      var value = $(this).val().trim().toUpperCase();
      if (value && !value.startsWith('B_')) {
        value = 'B_' + value;
      }
      $(this).val(value);
    });
  });