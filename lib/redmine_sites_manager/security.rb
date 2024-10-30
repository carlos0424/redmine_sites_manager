module RedmineSitesManager
    module Security
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
      end
  
      module ClassMethods
        def requires_sites_manager_admin
          include RedmineSitesManager::Security::InstanceMethods
          before_action :verify_sites_manager_access
        end
      end
  
      module InstanceMethods
        private
  
        def verify_sites_manager_access
          allowed_roles = Setting.plugin_redmine_sites_manager['allowed_roles'] || ['admin']
          
          has_access = allowed_roles.include?('admin') && User.current.admin? ||
                       User.current.roles.any? { |role| allowed_roles.include?(role.name) }
        
          unless has_access
            Rails.logger.warn "Acceso denegado a #{User.current.login} para RedmineSitesManager"
        
            if request.xhr?
              render json: { error: l('plugin_sites_manager.messages.access_denied') }, status: :forbidden
            else
              flash[:error] = l('plugin_sites_manager.messages.access_denied')
              redirect_back(fallback_location: home_path)
            end
            return false
          end
        end
        
      end
    end
  end