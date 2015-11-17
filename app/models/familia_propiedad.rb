class FamiliaPropiedad < ActiveRecord::Base
  self.table_name = "familias_propiedades"
  has_many :articulos_propiedades
  has_one :familia_valorligado 
  has_many :familias_valoresligados, class_name: "FamiliaValorligado", foreign_key: "fp_id"
  belongs_to :familia
  belongs_to :propiedad
  accepts_nested_attributes_for :familias_valoresligados , :allow_destroy => true
  validates :cod, length: { maximum: 10, too_long: "%{count} caracteres es lo máximo para codificar el código" }
  validates :separador, length: { maximum: 1 , message: "El separador debe 1 caracter"}
  default_scope order(:propiedad_id, :valor)
end

class FamiliaValorligado < ActiveRecord::Base
  self.table_name = "familias_valoresligados"
  belongs_to :familia_propiedad, foreign_key: "fp_id", inverse_of: :familia_valorligado
  belongs_to :familia_propiedadligada, class_name: "FamiliaPropiedad", foreign_key: "fp2_id"
  has_one :propiedad, through: :familia_propiedadligada
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
