class Propiedad < ActiveRecord::Base
  self.table_name = "propiedades"
  has_one :propiedadesComponerCorto, foreign_key: "componertcorto_id"
  has_one :propiedadesComponerLargo, foreign_key: "componertlargo_id"
  has_one :propiedadesComponerComercial, foreign_key: "componertcomercial_id"

  has_many :familias_propiedades
  default_scope order(:tlargo)
end
