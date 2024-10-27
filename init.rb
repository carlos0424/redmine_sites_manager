require 'redmine'

# Cargar dependencias del plugin
require_dependency 'redmine_sites_manager/hooks'

# Configuración de localización y carga de archivos de traducción
Rails.configuration.to_prepare do
  # Cargar archivos de traducción
  I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'config', 'locales', '*.yml')]
  
  # Establecer español como idioma predeterminado
  I18n.default_locale = :es
  
  # Forzar la recarga de traducciones
  I18n.reload!
  
  # Cargar patches y extensiones si se necesitan en el futuro
  # require_dependency 'redmine_sites_manager/patches/issue_patch'
end

# Registro del plugin en Redmine
Redmine::Plugin.register :redmine_sites_manager do
  # Propiedades básicas del plugin
  name I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM')
  author 'Carlos Arbelaez'
  description I18n.t('plugin_sites_manager.description', locale: :es, default: 'Plugin para gestión de sitios FLM')
  version '1.0.0'
  url 'https://your-repository-url.com'
  author_url 'https://your-website.com'

  # Requerimientos
  requires_redmine version_or_higher: '4.0.0'

  # Permisos
  permission :view_sites, { sites: [:index, :show, :search] }
  permission :manage_sites, { 
    sites: [:new, :create, :edit, :update, :destroy, :import, :toggle_status, :bulk_update]
  }

  # Menú de administración
  menu :admin_menu, 
       :sites_manager, 
       { controller: 'settings', action: 'plugin', id: 'redmine_sites_manager' },
       caption: -> { I18n.t('plugin_sites_manager.name', locale: :es, default: 'Gestor de Sitios FLM') },
       html: { class: 'icon icon-package' }

  # Configuraciones del plugin
  settings default: {
    'custom_fields_mapping' => {
      's_id' => '',
      'nom_sitio' => '',
      'identificador' => '',
      'depto' => '',
      'municipio' => '',
      'direccion' => '',
      'jerarquia_definitiva' => '',
      'fijo_variable' => '',
      'coordinador' => '',
      'electrificadora' => '',
      'nic' => '',
      'campo_adicional_3' => '',
      'campo_adicional_4' => '',
      'campo_adicional_5' => ''
    },
    'default_values' => {
      'active' => true
    },
    'search_settings' => {
      'min_chars' => 2,
      'max_results' => 10
    }
  }, 
  partial: 'settings/sites_manager_settings'
end

# Configurar hooks del plugin
Rails.application.config.after_initialize do
  # Registrar los hooks
  require_dependency 'redmine_sites_manager/hooks'
  
  # Configuraciones adicionales post-inicialización
  ActiveSupport::Dependencies.autoload_paths += [
    File.join(File.dirname(__FILE__), 'app', 'services'),
    File.join(File.dirname(__FILE__), 'app', 'presenters')
  ]
end

# Configurar manejador de assets
Rails.application.config.assets.precompile += %w( 
  sites_manager.css 
  sites_manager_admin.js 
  jquery-ui.min.js 
  select2.min.js 
  select2.min.css
)