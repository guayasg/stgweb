json.array!(@entidades) do |entidad|
  json.extract! entidad, :id, :nomentidad, :nomcomercial, :nif, :tipo_id, :espropia, :codentidad
  json.url entidad_url(entidad, format: :json)
end
