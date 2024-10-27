class SiteQuery
    attr_reader :criteria
  
    def initialize(criteria = {})
      @criteria = criteria
    end
  
    def self.build_from_params(params)
      criteria = {}
      
      if params[:search].present?
        criteria[:search] = params[:search].downcase
      end
  
      if params[:depto].present?
        criteria[:depto] = params[:depto]
      end
  
      if params[:municipio].present?
        criteria[:municipio] = params[:municipio]
      end
  
      if params[:fijo_variable].present?
        criteria[:fijo_variable] = params[:fijo_variable]
      end
  
      if params[:jerarquia_definitiva].present?
        criteria[:jerarquia_definitiva] = params[:jerarquia_definitiva]
      end
  
      new(criteria)
    end
  
    def results_scope(order: nil)
      scope = FlmSite.all
  
      if criteria[:search].present?
        search_term = "%#{criteria[:search]}%"
        scope = scope.where(
          "LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term OR LOWER(identificador) LIKE :term", 
          term: search_term
        )
      end
  
      if criteria[:depto].present?
        scope = scope.where(depto: criteria[:depto])
      end
  
      if criteria[:municipio].present?
        scope = scope.where(municipio: criteria[:municipio])
      end
  
      if criteria[:fijo_variable].present?
        scope = scope.where(fijo_variable: criteria[:fijo_variable])
      end
  
      if criteria[:jerarquia_definitiva].present?
        scope = scope.where(jerarquia_definitiva: criteria[:jerarquia_definitiva])
      end
  
      scope = scope.order(order) if order.present?
      
      scope
    end
  end