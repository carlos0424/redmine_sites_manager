require 'redmine'

# Configuración de localización y carga de archivos de traducción
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]
I18n.default_locale = :es
I18n.reload!

# Registro del plugin en Redmine
Redmine::Plugin.register :redmine_sites_manager do
  name I18n.t('plugin_sites_manager.name', default: 'Gestor de Sitios FLM')
  author 'Carlos Arbelaez'
  description I18n.t('plugin_sites_manager.description', default: 'Plugin para gestión de sitios FLM')
  version '1.0.0'

  # Agregar el plugin al menú de administración
  menu :admin_menu, 
       :sites_manager,
       { controller: 'sites', action: 'index' },
       caption: I18n.t('plugin_sites_manager.name'),
       html: { class: 'icon icon-package' },
       if: proc { User.current.admin? }

  # Configuración predeterminada y vista de ajustes
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
  }, partial: 'settings/sites_manager_settings'
end
