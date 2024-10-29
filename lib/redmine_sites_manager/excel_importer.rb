module RedmineSitesManager
  class ExcelImporter
    class ImportError < StandardError; end
    
    def self.import(file_path)
      new(file_path).import
    end
    
    def initialize(file_path)
      @file_path = file_path
      require 'roo'
    rescue LoadError
      raise ImportError, "Roo gem is required for Excel import"
    end
    
    def import
      case File.extname(@file_path).downcase
      when '.xlsx'
        spreadsheet = Roo::Excelx.new(@file_path)
      when '.xls'
        spreadsheet = Roo::Excel.new(@file_path)
      else
        raise ImportError, "Unsupported file format. Please use .xlsx or .xls"
      end
      
      ActiveRecord::Base.transaction do
        import_sites(spreadsheet)
      end
    rescue StandardError => e
      raise ImportError, "Import failed: #{e.message}"
    end
    
    private
    
    def import_sites(spreadsheet)
      # Asumiendo que la primera fila contiene los encabezados
      header = spreadsheet.row(1).map(&:downcase)
      
      # Mapeo de columnas Excel a campos de la base de datos
      column_mapping = {
        's_id' => header.index('s id'),
        'depto' => header.index('depto'),
        'municipio' => header.index('municipio'),
        'nom_sitio' => header.index('nom_sitio'),
        'direccion' => header.index('direccion'),
        'identificador' => header.index('identificador'),
        'jerarquia' => header.index('jerarquia'),
        'definitiva' => header.index('definitiva'),
        'fijo_variable' => header.index('fijo  / variable'),
        'coordinador' => header.index('coordinador'),
        'electrificadora' => header.index('electrificadora'),
        'nic' => header.index('nic'),
        'zona_operativa' => header.index('zona_operativa')
      }
      
      validate_columns(column_mapping)
      
      # Comenzar desde la segunda fila (después de los encabezados)
      (2..spreadsheet.last_row).each do |i|
        row = spreadsheet.row(i)
        site_attributes = {}
        
        column_mapping.each do |db_field, excel_index|
          next unless excel_index # Saltar columnas no encontradas
          site_attributes[db_field] = row[excel_index].to_s.strip
        end
        
        next if site_attributes['s_id'].blank? # Saltar filas sin ID
        
        # Buscar sitio existente o crear uno nuevo
        site = FlmSite.find_or_initialize_by(s_id: site_attributes['s_id'])
        site.assign_attributes(site_attributes)
        
        unless site.save
          raise ImportError, "Error en fila #{i}: #{site.errors.full_messages.join(', ')}"
        end
      end
    end
    
    def validate_columns(mapping)
      required_columns = ['s_id', 'nom_sitio']
      missing_columns = required_columns.select { |col| mapping[col].nil? }
      
      if missing_columns.any?
        raise ImportError, "Columnas requeridas no encontradas: #{missing_columns.join(', ')}"
      end
    end
  end
end

# Registrar el importador en el modelo FlmSite
class FlmSite < ActiveRecord::Base
  def self.import_from_excel(file_path)
    RedmineSitesManager::ExcelImporter.import(file_path)
  end
end
