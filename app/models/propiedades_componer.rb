class PropiedadesComponer < ActiveRecord::Base
  self.table_name = "propiedades_componer"
  belongs_to :propiedad
end
