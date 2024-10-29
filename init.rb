require 'redmine'

# Configuración de localización y carga de archivos de traducción en español
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]
I18n.default_locale = :es
I18n.reload! # Forzar la recarga de las traducciones para asegurar que se muestren en español

# Registro del plugin en Redmine
Redmine::Plugin.register :redmine_sites_manager do
  # Definición de las propiedades del plugin
  name I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM')
  author 'Carlos Arbelaez'
  description I18n.t('plugin_sites_manager.description', locale: :es, default: 'Plugin para gestión de sitios FLM')
  version '1.0.0'

  # Agregar el plugin al menú de administración de Redmine
  menu :admin_menu, 
       :sites_manager,
       { controller: 'sites', action: 'index' },
       caption: I18n.t('plugin_sites_manager.name', locale: :es),
       html: { class: 'icon icon-package' },
       if: proc { User.current.admin? }


  # Definición de configuraciones predeterminadas y asignación del formulario de ajustes
  settings default: {
    'custom_fields_mapping' => {
      'sitio' => '',
      'direccion' => '',
      'jerarquia_definitiva' => '',
      'municipio' => '',
      'coordinador' => '',
      'electrificadora' => '',
      'nic' => '',
      'zona_operativa' => '',
      'campo_adicional_4' => '',
      'campo_adicional_5' => ''
    }
  }, partial: 'settings/sites_manager_settings' # Vista parcial para gestionar configuraciones en la UI de Redmine
end