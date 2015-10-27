class Familia < ActiveRecord::Base
  require "will_paginate"
  self.table_name = "familias"
  has_many :familias_propiedades, :class_name => 'FamiliaPropiedad'
  accepts_nested_attributes_for :familias_propiedades #, :allow_destroy => true
  has_many :propiedades, through: :familias_propiedades 
  has_many :articulos
  accepts_nested_attributes_for :articulos #, :allow_destroy => true

end


