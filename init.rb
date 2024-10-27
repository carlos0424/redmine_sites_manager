require 'redmine'
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]

Redmine::Plugin.register :redmine_sites_manager do
  name I18n.t('plugin_sites_manager.name', default: 'Sites Manager') # Cargar con valor predeterminado
  author 'Carlos Arbelaez'
  description I18n.t('plugin_sites_manager.description', default: 'Plugin para gestión de sitios FLM')
  version '1.0.0'

  menu :admin_menu, :sites_manager, 
       { controller: 'settings', action: 'plugin', id: 'redmine_sites_manager' },
       caption: I18n.t('plugin_sites_manager.name', default: 'Sites Manager'),
       html: { class: 'icon icon-package' }

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
