class Propiedad < ActiveRecord::Base
  self.table_name = "propiedades"
  has_one :propiedadesComponer, foreign_key: "componertcorto_id"
  has_one :propiedadesComponer, foreign_key: "componertlargo_id"
  has_one :propiedadesComponer, foreign_key: "componertcomercial_id"
<<<<<<< HEAD
  has_many :familias_propiedades
=======
>>>>>>> 9b1d472ce5ca41fa2bdeca7a84a77f3fad8310e8
end
