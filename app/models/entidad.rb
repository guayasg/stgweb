class Entidad < ActiveRecord::Base
  self.table_name = "entidades"
  has_many :direcciones, class_name: "Direccion"
  belongs_to :entidad_tipo, class_name: "EntidadTipo", foreign_key: "tipo_id"
  
  has_many :subordinados, class_name: "EntidadLink", foreign_key: "entidadlinkpadre_id"
  has_many :superiores, class_name: "EntidadLink", foreign_key: "entidadlink_id"
  has_many :entidades_subordinadas, through: :subordinados, source: :superior
  has_many :entidades_superiores, through: :superiores, source: :subordinado
  
  #has_many :entidades_superiores, through: :superior
  belongs_to :grupoventa, class_name: "Grupoventa", foreign_key: "grupoventa_id"
  
     
  
end

class EntidadTipo < ActiveRecord::Base
  self.table_name = "entidades_tipos"
  has_many :entidades 
end

class EntidadLink < ActiveRecord::Base
  self.table_name = "entidades_links"
  belongs_to :subordinado, class_name: "Entidad", foreign_key: "entidadlinkpadre_id"
  belongs_to :superior, class_name: "Entidad", foreign_key: "entidadlink_id"
   
  
  #has_many :entidad_subordinada,  foreign_key: "entidadlik_id"
  #has_one :entidad_superior, through: :superior
end


class Grupoventa < ActiveRecord::Base
  self.table_name = "gruposventas"
  has_many :entidades
end

class Direccion < ActiveRecord::Base
  self.table_name = "direcciones"
  belongs_to :entidad, foreign_key: "entidad_id"
end


