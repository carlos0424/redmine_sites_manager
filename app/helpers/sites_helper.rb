# app/helpers/sites_helper.rb
module SitesHelper
  SITE_FIELDS = {
    s_id: 'field_s_id',
    nom_sitio: 'field_nom_sitio',
    municipio: 'field_municipio',
    direccion: 'field_direccion',
    jerarquia: 'field_jerarquia',
    fijo_variable: 'field_fijo_variable'
  }.freeze

  STATUS_CLASSES = {
    active: 'status-active',
    inactive: 'status-inactive'
  }.freeze

  # Formateo y presentación
  def format_site_status(status)
    css_class = STATUS_CLASSES[status.to_sym] || STATUS_CLASSES[:inactive]
    content_tag(:span, status.capitalize, class: css_class)
  end

  def format_site_link(site)
    return unless site
    link_to "#{site.s_id} - #{site.nom_sitio}", 
            edit_site_path(site),
            title: site.direccion,
            class: 'site-link'
  end

  def format_site_field(site, field)
    return '-' if site.nil? || !site.respond_to?(field)
    
    value = site.public_send(field)
    return '-' if value.blank?
    
    case field.to_sym
    when :fijo_variable
      format_fijo_variable(value)
    when :jerarquia
      format_jerarquia(value)
    else
      h(value)
    end
  end

  # Opciones para selectores
  def site_status_options
    [
      [l('plugin_sites_manager.status.active'), 'active'],
      [l('plugin_sites_manager.status.inactive'), 'inactive']
    ]
  end

  def site_fijo_variable_options
    [
      [l('plugin_sites_manager.fijo_variable.fijo'), 'FIJO'],
      [l('plugin_sites_manager.fijo_variable.variable'), 'VARIABLE']
    ]
  end

  # Navegación y breadcrumbs
  def site_breadcrumb(site = nil)
    items = []
    items << link_to(l('plugin_sites_manager.sites.title'), sites_path)
    
    if site
      items << (site.persisted? ? site.nom_sitio : l('plugin_sites_manager.sites.new'))
    end
    
    breadcrumb(*items)
  end

  # Elementos de formulario
  def render_site_custom_fields_form(form)
    return unless form
    
    content_tag(:div, class: 'box tabular') do
      safe_join(build_custom_field_tags(form))
    end
  end

  def site_error_messages(site, field)
    return unless site&.errors&.include?(field)
    
    content_tag(:span, 
                site.errors.full_messages_for(field).join(", "), 
                class: 'error')
  end

  # Tablas y listados
  def site_table_header
    content_tag(:tr) do
      safe_join([
        *SITE_FIELDS.map { |field, label_key| content_tag(:th, l("plugin_sites_manager.#{label_key}")) },
        content_tag(:th, l(:label_status)),
        content_tag(:th, l(:button_actions), style: 'width: 150px')
      ])
    end
  end

  def site_table_actions(site)
    return unless site
    
    actions = [
      edit_action(site),
      toggle_status_action(site),
      delete_action(site)
    ]
    
    safe_join(actions, ' ')
  end

  # Filtros
  def render_site_filters
    form_tag(sites_path, method: :get, id: 'sites-filters') do
      content_tag(:div, class: 'filters') do
        safe_join([
          search_filter,
          status_filter,
          type_filter,
          apply_button
        ])
      end
    end
  end

  private

  def format_fijo_variable(value)
    content_tag(:span, value, class: "site-#{value.downcase}")
  end

  def format_jerarquia(value)
    content_tag(:span, value, class: 'site-hierarchy')
  end

  def build_custom_field_tags(form)
    site_custom_field_values(form).map do |value|
      custom_field_tag_with_label(value)
    end
  end

  def custom_field_tag_with_label(custom_value)
    return unless custom_value
    custom_field = custom_value.custom_field
    
    content_tag(:p) do
      safe_join([
        custom_field_label_tag(custom_field),
        custom_field_tag(custom_value),
        custom_field_description(custom_field)
      ].compact)
    end
  end

  def custom_field_description(custom_field)
    return unless custom_field.description.present?
    
    safe_join([
      tag(:br),
      content_tag(:em, custom_field.description, class: 'info')
    ])
  end

  def edit_action(site)
    link_to l(:button_edit), 
            edit_site_path(site), 
            class: 'icon icon-edit'
  end

  def toggle_status_action(site)
    link_to toggle_status_label(site),
            toggle_status_site_path(site),
            method: :post,
            remote: true,
            class: "icon #{toggle_status_icon(site)}"
  end

  def delete_action(site)
    link_to l(:button_delete),
            site_path(site),
            method: :delete,
            data: { confirm: l(:text_are_you_sure) },
            class: 'icon icon-del'
  end

  def toggle_status_label(site)
    key = site.active? ? 'button_deactivate' : 'button_activate'
    l("plugin_sites_manager.#{key}")
  end

  def toggle_status_icon(site)
    site.active? ? 'icon-unlock' : 'icon-lock'
  end

  def search_filter
    text_field_tag(:search, 
                  params[:search], 
                  placeholder: l('plugin_sites_manager.sites.search'),
                  class: 'sites-search')
  end

  def status_filter
    select_tag(:status, 
               options_for_select(site_status_options, params[:status]),
               prompt: l(:label_all),
               class: 'sites-status-filter')
  end

  def type_filter
    select_tag(:fijo_variable,
               options_for_select(site_fijo_variable_options, params[:fijo_variable]),
               prompt: l(:label_all),
               class: 'sites-type-filter')
  end

  def apply_button
    submit_tag(l(:button_apply), name: nil, class: 'button-positive')
  end

  def cancel_button
    link_to l(:button_cancel), sites_path, class: 'button'
  end
end