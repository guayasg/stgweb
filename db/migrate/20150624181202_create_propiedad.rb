class CreatePropiedad < ActiveRecord::Migration
  def change
    create_table :propiedad do |t|
      t.string :codpropiedad
      t.text :tcorto
      t.text :tlargo
      t.text :tcomercial
      t.integer :componertcorto_id
      t.integer :componertlargo_id
      t.integer :componertcomercial_id
      t.boolean :propnumerica

      t.timestamps
    end
  end
end
