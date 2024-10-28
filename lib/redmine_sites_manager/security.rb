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
          unless User.current.admin?
            if request.xhr?
              render json: { error: l('plugin_sites_manager.messages.access_denied') }, 
                     status: :forbidden
            else
              flash[:error] = l('plugin_sites_manager.messages.access_denied')
              redirect_to home_path
            end
            return false
          end
        end
      end
    end
  end