require 'redmine'
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]

# Forzar el uso del idioma español en Redmine
I18n.default_locale = :es
I18n.reload!  # Forzar la recarga de las traducciones

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

  Rails.application.config.assets.precompile += %w(
    sites_manager.css
    jquery-ui.min.js
    select2.min.js
  )
end
