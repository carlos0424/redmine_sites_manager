class CreateFlmSites < ActiveRecord::Migration[5.2]
  def up
    unless table_exists?(:flm_sites)
      create_table :flm_sites do |t|
        t.string :s_id, null: false
        t.string :depto
        t.string :municipio
        t.string :nom_sitio
        t.string :direccion
        t.string :identificador
        t.string :jerarquia_definitiva
        t.string :fijo_variable
        t.string :coordinador
        t.string :electrificadora
        t.string :nic
        t.string :zona_operativa
        
        # Campos adicionales para futuro crecimiento
        t.string :campo_adicional_4
        t.string :campo_adicional_5
        
        t.boolean :active, default: true
        t.timestamps
      end
      
      add_index :flm_sites, :s_id, unique: true
      add_index :flm_sites, :nom_sitio
      add_index :flm_sites, [:depto, :municipio]
    end
  end

  def down
    drop_table :flm_sites if table_exists?(:flm_sites)
  end
end
