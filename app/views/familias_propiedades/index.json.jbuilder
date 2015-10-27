json.array!(@familias_propiedades) do |familia_propiedad|
  json.extract! familia_propiedad, :id
  json.url familia_propiedad_url(familia_propiedad, format: :json)
end
