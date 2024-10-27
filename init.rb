require 'redmine'

Redmine::Plugin.register :redmine_sites_manager do
  name 'Sites Manager'
  author 'Your Name'
  description 'Plugin para gestión y búsqueda de sitios FLM'
  version '1.0.0'
  
  menu :admin_menu, :sites_manager, 
       { controller: 'sites', action: 'index' },
       caption: :plugin_sites_manager_name,
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
