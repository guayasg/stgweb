json.array!(@propiedades) do |propiedad|
  json.extract! propiedad, :id, :codpropiedad, :tcorto, :tlargo, :tcomercial, :componertcorto_id, :componertlargo_id, :componertcomercial_id, :propnumerica
  json.url propiedad_url(propiedad, format: :json)
end
