# lib/redmine_sites_manager/hooks.rb
module RedmineSitesManager
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context={})
      return unless should_include_assets?(context)
      
      stylesheet = stylesheet_link_tag('sites_manager', plugin: 'redmine_sites_manager')
      javascript = javascript_include_tag('sites_manager_admin', plugin: 'redmine_sites_manager')
      javascript_include_tag('jquery-ui.min', plugin: 'redmine_sites_manager') +
      stylesheet +
      javascript
    end

    def view_issues_form_details_top(context={})
    return '' unless show_site_search?(context[:issue])
    
    html = <<-HTML
      <div class="sites-search-container">
        <p class="site-search-wrapper">
          <label>#{l('plugin_sites_manager.sites.search_label')}</label>
          <div style="position: relative;">
            <input type="text" 
                   id="sites-search-field" 
                   class="sites-autocomplete" 
                   placeholder="#{l('plugin_sites_manager.search.placeholder')}" 
                   autocomplete="off" />
            <span class="sites-clear-btn" 
                  title="#{l('plugin_sites_manager.sites.clear_selection')}">×</span>
          </div>
        </p>
      </div>
    HTML
    
    html.html_safe
  end

    private

    def should_include_assets?(context)
      return false unless context[:controller]
      controller = context[:controller]
      
      # Incluir assets solo en controladores relevantes
      controller.is_a?(IssuesController) || 
      controller.is_a?(SitesController)
    end

    def show_site_search?(issue)
      return true if issue.nil? || issue.new_record?
      
      # Permitir edición solo en estados específicos
      allowed_statuses = Setting.plugin_redmine_sites_manager['allowed_statuses'] || ['1']
      allowed_statuses.include?(issue.status_id.to_s)
    end
  end
end