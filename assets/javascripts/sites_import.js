// Crear nuevo archivo: assets/javascripts/sites_import.js
$(function() {
    const form = $('.import-form');
    const submitButton = form.find('input[type="submit"]');
    const originalButtonText = submitButton.val();
  
    form.on('submit', function(e) {
      if (!$('input[type="file"]').val()) {
        e.preventDefault();
        alert(I18n.t('plugin_sites_manager.messages.no_file'));
        return;
      }
  
      submitButton.val(I18n.t('plugin_sites_manager.messages.importing')).prop('disabled', true);
      submitButton.after('<span class="import-spinner"> ⌛</span>');
    });
  });

  // Agregar al archivo sites_import.js
$(function() {
    const fileInput = $('.file-input');
    
    fileInput.on('change', function() {
      const file = this.files[0];
      if (file) {
        // Validar extensión
        const extension = file.name.split('.').pop().toLowerCase();
        if (extension !== 'csv') {
          alert(I18n.t('plugin_sites_manager.messages.invalid_file_type'));
          this.value = '';
          return;
        }
        
        // Validar tamaño (5MB máximo)
        if (file.size > 5 * 1024 * 1024) {
          alert(I18n.t('plugin_sites_manager.messages.file_too_large'));
          this.value = '';
          return;
        }
      }
    });
  });