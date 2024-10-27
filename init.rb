require 'redmine'
require_dependency File.expand_path('redmine_sites_manager/hooks', __dir__)  # Cargar hooks con ruta absoluta para evitar errores de carga

# Agregar archivos de localización para el plugin
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]
I18n.default_locale = :es  # Forzar el idioma español para Redmine

Redmine::Plugin.register :redmine_sites_manager do
  name I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM')
  author 'Carlos Arbelaez'
  description I18n.t('plugin_sites_manager.description', locale: :es, default: 'Plugin para gestión de sitios FLM')
  version '1.0.0'
  
  # Configurar el menú del administrador
  menu :admin_menu, :sites_manager, 
       { controller: 'settings', action: 'plugin', id: 'redmine_sites_manager' },
       caption: I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM'),
       html: { class: 'icon icon-package' }

  # Configuración por defecto del plugin
  settings default: {
    'custom_fields_mapping' => {
      'sitio' => '',
      'direccion' => '',
      'jerarquia_definitiva' => '',
      'municipio' => '',
      'coordinador' => '',
      'campo_adicional_1' => '',
      'campo_adicional_2' => '',
      'campo_adicional_3' => '',
      'campo_adicional_4' => '',
      'campo_adicional_5' => ''
    }
  }, partial: 'settings/sites_manager_settings'
end
