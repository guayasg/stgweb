class FamiliaPropiedad < ActiveRecord::Base
  self.table_name = "familias_propiedades"
  has_many :articulos_propiedades
  has_one :familia_valorligado, inverse_of: :familias_propiedades
  has_many :familias_valoresligados
  belongs_to :familia
  belongs_to :propiedad
end

class FamiliaValorligado < ActiveRecord::Base
  self.table_name = "familias_valoresligados"
  belongs_to :familia_propiedad, foreign_key: "fp_id", inverse_of: :familia_valorligado
  belongs_to :familia_propiedad, foreign_key: "fp2_id", inverse_of: :familias_valoresligados
end


class Articulo < ActiveRecord::Base
  self.table_name ="articulos"
  belongs_to :familia
  has_many :articulos_propiedades
  accepts_nested_attributes_for :articulos_propiedades
end  


class ArticuloPropiedad < ActiveRecord::Base
  self.table_name ="articulos_propiedades"
  belongs_to :articulo, foreign_key: 'grupo_id', class_name: 'articulo'
  belongs_to :familia_propiedad, class_name: 'FamiliaPropiedad' 
end  
