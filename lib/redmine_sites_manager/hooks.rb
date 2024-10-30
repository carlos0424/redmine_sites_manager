# lib/redmine_sites_manager/hooks.rb
module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context={})
      return unless should_include_assets?(context)
      
      stylesheet = stylesheet_link_tag('sites_manager', plugin: 'redmine_sites_manager')
      javascript = javascript_include_tag('sites_dynamic_search', plugin: 'redmine_sites_manager')
      "#{stylesheet}\n#{javascript}".html_safe
    end

    def view_issues_form_details_top(context={})
      return '' unless show_site_search?(context[:issue])
      
      html = <<-HTML
        <div class="sites-search-container">
          <p class="site-search-wrapper">
            <label>#{l('plugin_sites_manager.sites.search_label')}</label>
            <input type="text" 
                   id="sites-search-field" 
                   class="sites-autocomplete" 
                   placeholder="#{l('plugin_sites_manager.search.placeholder')}" 
                   data-mapping='#{custom_fields_mapping.to_json}'
                   autocomplete="off" />
            <span class="sites-clear-btn" title="#{l('plugin_sites_manager.sites.clear_selection')}">×</span>
          </p>
        </div>
      HTML
      
      html.html_safe
    end

    private

    def should_include_assets?(context)
      return false unless context[:controller]
      
      controller = context[:controller]
      return true if controller.is_a?(IssuesController)
      return true if controller.is_a?(SitesController)
      
      false
    end

    def show_site_search?(issue)
      return true if issue.nil? || issue.new_record?
      
      # Permitir edición solo en ciertos estados
      allowed_statuses = Setting.plugin_redmine_sites_manager['allowed_statuses'] || ['1']
      allowed_statuses.include?(issue.status_id.to_s)
    end

    def custom_fields_mapping
      @custom_fields_mapping ||= begin
        mapping = Setting.plugin_redmine_sites_manager['custom_fields_mapping'] || {}
        mapping.transform_values do |field_id|
          next unless field_id.present?
          CustomField.find_by(id: field_id)&.id
        end.compact
      end
    end
  end

  class ViewListener < Redmine::Hook::ViewListener
    render_on :view_layouts_base_body_bottom,
              partial: 'sites_manager/global_scripts'
  end
end