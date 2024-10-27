module SitesHelper
  def format_site_status(status)
    css_class = status == 'active' ? 'status-active' : 'status-inactive'
    content_tag(:span, status.capitalize, class: css_class)
  end

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

  def format_site_link(site)
    link_to "#{site.s_id} - #{site.nom_sitio}", 
            edit_site_path(site),
            title: site.direccion
  end

  def site_breadcrumb(site = nil)
    items = []
    items << link_to(l('plugin_sites_manager.sites.title'), sites_path)
    
    if site&.persisted?
      items << site.nom_sitio
    elsif site
      items << l('plugin_sites_manager.sites.new')
    end
    
    breadcrumb(*items)
  end

  def render_site_custom_fields_form(f)
    content_tag(:div, class: 'box tabular') do
      site_custom_field_values(f).each do |value|
        concat custom_field_tag_with_label(value)
      end
    end
  end

  def custom_field_tag_with_label(custom_value)
    custom_field = custom_value.custom_field
    
    content_tag(:p) do
      concat custom_field_label_tag(custom_field)
      concat custom_field_tag(custom_value)
      if custom_field.description.present?
        concat content_tag(:br)
        concat content_tag(:em, custom_field.description, class: 'info')
      end
    end
  end
  
  def cancel_button
    link_to l(:button_cancel), sites_path, class: 'button'
  end
  
  def site_error_messages(site, field)
    if site.errors.include?(field)
      content_tag(:span, site.errors.full_messages_for(field).join(", "), class: 'error')
    end
  end
  def site_table_header
    content_tag(:tr) do
      concat content_tag(:th, l('plugin_sites_manager.field_s_id'))
      concat content_tag(:th, l('plugin_sites_manager.field_nom_sitio'))
      concat content_tag(:th, l('plugin_sites_manager.field_municipio'))
      concat content_tag(:th, l('plugin_sites_manager.field_direccion'))
      concat content_tag(:th, l('plugin_sites_manager.field_jerarquia'))
      concat content_tag(:th, l('plugin_sites_manager.field_fijo_variable'))
      concat content_tag(:th, l(:label_status))
      concat content_tag(:th, l(:button_actions), style: 'width: 150px')
    end
  end

  def site_table_actions(site)
    actions = []
    
    actions << link_to(l(:button_edit), 
                      edit_site_path(site), 
                      class: 'icon icon-edit')
                      
    actions << link_to(site.active? ? l('plugin_sites_manager.button_deactivate') : l('plugin_sites_manager.button_activate'),
                      toggle_status_site_path(site),
                      method: :post,
                      remote: true,
                      class: "icon #{site.active? ? 'icon-unlock' : 'icon-lock'}")
                      
    actions << link_to(l(:button_delete),
                      site_path(site),
                      method: :delete,
                      data: { confirm: l(:text_are_you_sure) },
                      class: 'icon icon-del')
                      
    actions.join(' ').html_safe
  end

  def format_site_field(site, field)
    value = site.send(field)
    return '-' if value.blank?
    
    case field
    when :fijo_variable
      content_tag(:span, value, class: "site-#{value.downcase}")
    when :jerarquia
      content_tag(:span, value, class: 'site-hierarchy')
    else
      h(value)
    end
  end

  def render_site_filters
    form_tag(sites_path, method: :get, id: 'sites-filters') do
      content_tag(:div, class: 'filters') do
        concat text_field_tag(:search, params[:search], 
                            placeholder: l('plugin_sites_manager.sites.search'),
                            class: 'sites-search')
        concat select_tag(:status, 
                         options_for_select(site_status_options, params[:status]),
                         prompt: l(:label_all),
                         class: 'sites-status-filter')
        concat select_tag(:fijo_variable,
                         options_for_select(site_fijo_variable_options, params[:fijo_variable]),
                         prompt: l(:label_all),
                         class: 'sites-type-filter')
        concat submit_tag(l(:button_apply), name: nil, class: 'button-positive')
      end
    end
  end
end
