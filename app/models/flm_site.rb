class FlmSite < ActiveRecord::Base
  include Redmine::Pagination
  
  # Validaciones
  validates :s_id, presence: true, uniqueness: true
  validates :nom_sitio, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_depto, ->(depto) { where(depto: depto) }
  scope :by_municipio, ->(municipio) { where(municipio: municipio) }
  
  def self.search(term)
    where("LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term", 
          term: "%#{term.downcase}%")
  end
  
  def self.import_from_excel(file_path)
    require 'roo'
    
    spreadsheet = case File.extname(file_path)
    when '.xlsx' then Roo::Excelx.new(file_path)
    when '.xls' then Roo::Excel.new(file_path)
    else raise "Formato de archivo no soportado. Use .xlsx o .xls"
    end
    
    header = spreadsheet.row(1).map(&:downcase)
    
    # Mapeo de columnas
    columns = {
      's_id' => header.index('s id'),
      'depto' => header.index('depto'),
      'municipio' => header.index('municipio'),
      'nom_sitio' => header.index('nom_sitio'),
      'direccion' => header.index('direccion'),
      'identificador' => header.index('identificador'),
      'jerarquia' => header.index('jerarquia'),
      'definitiva' => header.index('definitiva'),
      'fijo_variable' => header.index('fijo  / variable'),
      'coordinador' => header.index('coordinador')
    }
    
    # Validar columnas requeridas
    unless columns['s_id'] && columns['nom_sitio']
      raise "Columnas requeridas no encontradas: S ID y NOM_SITIO son obligatorias"
    end
    
    # Importar datos
    (2..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      attributes = {}
      
      columns.each do |field, index|
        next unless index
        attributes[field] = row[index].to_s.strip
      end
      
      # Buscar o crear sitio
      site = find_or_initialize_by(s_id: attributes['s_id'])
      site.assign_attributes(attributes)
      site.save!
    end
  end
end
