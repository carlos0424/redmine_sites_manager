require 'redmine'
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]

# Forzar el uso del idioma español
I18n.locale = :es

Redmine::Plugin.register :redmine_sites_manager do
  name I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM')
  author 'Carlos Arbelaez'
  description I18n.t('plugin_sites_manager.description', locale: :es, default: 'Plugin para gestión de sitios FLM')
  version '1.0.0'

  menu :admin_menu, :sites_manager, 
       { controller: 'settings', action: 'plugin', id: 'redmine_sites_manager' },
       caption: I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM'),
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
Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :sites_manager,
            { controller: 'sites', action: 'index' },
            caption: :label_sites_manager,
            html: { class: 'icon icon-sites' }
end