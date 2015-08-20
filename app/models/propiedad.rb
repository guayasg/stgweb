class Propiedad < ActiveRecord::Base
  self.table_name = "propiedades"
  has_one :propiedadesComponer, foreign_key: "componertcorto_id"
  has_one :propiedadesComponer, foreign_key: "componertlargo_id"
  has_one :propiedadesComponer, foreign_key: "componertcomercial_id"
end
