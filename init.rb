require 'redmine'

Redmine::Plugin.register :redmine_sites_manager do
  name I18n.t('plugin_sites_manager.name') # Llamada directa a I18n.t para cargar el nombre traducido
  author 'Carlos Arbelaez'
  description 'Plugin para gestión y búsqueda de sitios FLM'
  version '1.0.0'

  # Menú en la administración que apunta directamente a la configuración del plugin
  menu :admin_menu, :sites_manager, 
       { controller: 'settings', action: 'plugin', id: 'redmine_sites_manager' },
       caption: I18n.t('plugin_sites_manager.name'), # Uso directo de I18n.t para cargar el nombre
       html: { class: 'icon icon-package' }

  # Configuración del plugin
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
