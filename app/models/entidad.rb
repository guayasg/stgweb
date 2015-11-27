class Entidad < ActiveRecord::Base
  self.table_name = "entidades"
  has_many :direcciones
  belongs_to :entidad_tipo, class_name: "EntidadTipo", foreign_key: "tipo_id"
  has_many :superiores, class_name: "EntidadLink", foreign_key: "entidadlinkpadre_id"
  has_many :subordinados, class_name: "EntidadLink", foreign_key: "entidadlink_id"
  has_many :padres, :throught => :superiores
  has_many :hijos, :throught => :subordinados  
  has_one :entidades_gruposventas, class_name: "EntidadGrupoventa"
end

class EntidadTipo < ActiveRecord::Base
  self.table_name = "entidades_tipos"
  has_many :entidades 
end

class Entidadlink < ActiveRecord::Base
  self.table_name = "entidades_links"
  belongs_to
  
end


class EntidadGrupoventa < ActiveRecord::Base
  self.table_name = "entidades_gruposventas"
end

class Direccion < ActiveRecord::Base
  
end


