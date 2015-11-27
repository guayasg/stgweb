class CreateEntidad < ActiveRecord::Migration
  def change
    create_table :entidad do |t|
      t.string :nomentidad
      t.string :nomcomercial
      t.string :nif
      t.integer :tipo_id
      t.boolean :espropia
      t.string :codentidad

      t.timestamps
    end
  end
end
