class Entidad < ActiveRecord::Base
  self.table_name = "entidades"
  has_many :direcciones
  belongs_to :entidad_tipo, class_name: "EntidadTipo", foreign_key: "tipo_id"
  has_many :superiores, class_name: "EntidadLink", foreign_key: "entidadlinkpadre_id"
  has_many :subordinados, class_name: "EntidadLink", foreign_key: "entidadlink_id"
  has_many :padres, :through => :superiores
  has_many :hijos, :through => :subordinados  
  belongs_to :grupoventa, class_name: "Grupoventa", foreign_key: "grupoventa_id"
  has_many :direcciones
  
end

class EntidadTipo < ActiveRecord::Base
  self.table_name = "entidades_tipos"
  has_many :entidades 
end

class Entidadlink < ActiveRecord::Base
  self.table_name = "entidades_links"
  belongs_to :padre, class_name: "Entidad", foreign_key: "entidadlikpadre_id"
  belongs_to :hijo, class_name: "Entidad", foreign_key: "entidadlik_id"
end


class Grupoventa < ActiveRecord::Base
  self.table_name = "gruposventas"
  has_many :entidades
end

class Direccion < ActiveRecord::Base
  self.table_name="direcciones"
  belongs_to :entidad
end


