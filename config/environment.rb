# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.

# Limpiamos todas las inflecciones existentes
#ActiveSupport::Inflector.inflections.clear

# Agregamos las reglas de inflección
ActiveSupport::Inflector.inflections do |inflect|
  inflect.plural /([taeiou])([A-Z]|_|\$)/, '\1s\2'
  inflect.plural /([rlnd])([A-Z]|_|$)/, '\1es\2'
  inflect.singular /([taeiou])s([A-Z]|_|$)/, '\1\2'
  inflect.singular /([rlnd])es([A-Z]|_|$)/, '\1\2'

  inflect.plural 'familia', 'familias'
  inflect.plural 'familia_propiedad', 'familias_propiedades'
  inflect.plural 'familias_valorligado', 'familias_valoresligados'
end

ActiveRecord::Base.pluralize_table_names = false
Stgweb::Application.initialize!

#require "will_paginate"
