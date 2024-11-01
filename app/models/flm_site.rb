class FlmSite < ActiveRecord::Base
  include Redmine::Pagination
  

  # Validaciones
  validates :s_id, presence: true, uniqueness: true, format: { with: /\AS\d+\z/, message: "debe comenzar con 'S' seguido de números" }
  validates :nom_sitio, presence: true

  # Atributos accesibles
  attr_accessible :s_id, 
                  :depto, 
                  :municipio, 
                  :nom_sitio, 
                  :direccion, 
                  :identificador, 
                  :jerarquia_definitiva, 
                  :fijo_variable, 
                  :coordinador,
                  :electrificadora,
                  :nic,
                  :zona_operativa,
                  :campo_adicional_4,
                  :campo_adicional_5

  # Callbacks
  before_save :format_attributes
  before_validation :normalize_s_id
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_depto, ->(depto) { where("LOWER(depto) = LOWER(?)", depto) }
  scope :by_municipio, ->(municipio) { where("LOWER(municipio) = LOWER(?)", municipio) }
  scope :by_jerarquia, ->(jerarquia) { where(jerarquia_definitiva: jerarquia) }
  scope :fijos, -> { where(fijo_variable: 'FIJO') }
  scope :variables, -> { where(fijo_variable: 'VARIABLE') }
  scope :ordered, -> { order(:s_id) }
  
  def self.search(term)
    term = term.to_s.strip.downcase
    where("LOWER(s_id) LIKE :term OR LOWER(nom_sitio) LIKE :term OR LOWER(identificador) LIKE :term", 
          term: "%#{term}%")
  end
  
  def self.import_from_excel(file_path)
    require 'roo'
    
    # Validar archivo
    raise "Archivo no encontrado" unless File.exist?(file_path)
    
    spreadsheet = case File.extname(file_path).downcase
    when '.xlsx' then Roo::Excelx.new(file_path)
    when '.xls' then Roo::Excel.new(file_path)
    else raise "Formato de archivo no soportado. Use .xlsx o .xls"
    end
    
    header = spreadsheet.row(1).map { |h| h.to_s.downcase.strip }
    
    # Mapeo de columnas
    columns = {
      's_id' => header.index('s id'),
      'depto' => header.index('depto'),
      'municipio' => header.index('municipio'),
      'nom_sitio' => header.index('nom_sitio'),
      'direccion' => header.index('direccion'),
      'identificador' => header.index('identificador'),
      'jerarquia_definitiva' => header.index('jerarquia definitiva'),
      'fijo_variable' => header.index('fijo / variable'),
      'coordinador' => header.index('coordinador'),
      'electrificadora' => header.index('electrificadora'),
      'nic' => header.index('nic'),
      'zona_operativa' => header.index('zona_operativa'),
      'campo_adicional_4' => header.index('campo adicional 4'),
      'campo_adicional_5' => header.index('campo adicional 5')
    }
    
    # Validar columnas requeridas
    required_columns = ['s_id', 'nom_sitio']
    missing_columns = required_columns.select { |col| columns[col].nil? }
    raise "Columnas requeridas no encontradas: #{missing_columns.join(', ')}" if missing_columns.any?
    
    # Inicializar contadores
    results = { imported: 0, updated: 0, failed: 0, errors: [] }
    
    # Importar datos
    ActiveRecord::Base.transaction do
      (2..spreadsheet.last_row).each do |i|
        begin
          row = spreadsheet.row(i)
          attributes = {}
          
          columns.each do |field, index|
            next unless index
            value = row[index].to_s.strip
            attributes[field] = value unless value.blank?
          end
          
          next if attributes['s_id'].blank?
          
          # Buscar o crear sitio
          site = find_or_initialize_by(s_id: attributes['s_id'])
          is_new = site.new_record?
          
          if site.update(attributes)
            is_new ? results[:imported] += 1 : results[:updated] += 1
          else
            results[:failed] += 1
            results[:errors] << "Fila #{i}: #{site.errors.full_messages.join(', ')}"
          end
          
        rescue StandardError => e
          results[:failed] += 1
          results[:errors] << "Fila #{i}: #{e.message}"
        end
      end
    end
    
    results
  end
  
  def to_s
    "#{s_id} - #{nom_sitio}"
  end
  
  def active?
    active
  end
  
  def toggle_status!
    update(active: !active)
  end

  def to_json_for_autocomplete
    {
      id: id,
      label: to_s,
      value: nom_sitio,
      sitio_data: {
        s_id: s_id,
        depto: depto,
        municipio: municipio,
        direccion: direccion,
        identificador: identificador,
        jerarquia_definitiva: jerarquia_definitiva,
        fijo_variable: fijo_variable,
        coordinador: coordinador,
        electrificadora: electrificadora,
        nic: nic,
        zona_operativa: zona_operativa,
        campo_adicional_4: campo_adicional_4,
        campo_adicional_5: campo_adicional_5
      }
    }
  end
  
  private

  def format_attributes
    self.s_id = s_id.to_s.upcase if s_id
    self.depto = depto.to_s.upcase if depto
    self.municipio = municipio.to_s.upcase if municipio
    self.fijo_variable = fijo_variable.to_s.capitalize if fijo_variable
  end
  
  def normalize_s_id
    return if s_id.blank?
    
    # Limpiar el valor
    normalized = s_id.to_s.strip.upcase
    
    # Si es solo números, agregar la S
    if normalized =~ /^\d+$/
      normalized = "S#{normalized}"
    # Si no empieza con S y tiene números, agregar la S
    elsif normalized !~ /^S/ && normalized =~ /\d+/
      normalized = "S#{normalized.gsub(/[^0-9]/, '')}"
    end
    
    self.s_id = normalized
  end

  scope :for_export, -> {
    select(
      :s_id,
      :depto,
      :municipio,
      :nom_sitio,
      :direccion,
      :identificador,
      :jerarquia_definitiva,
      :fijo_variable,
      :coordinador,
      :electrificadora,
      :nic,
      :zona_operativa,
      :campo_adicional_4,
      :campo_adicional_5
    ).order(:s_id)
  }
end