json.array!(@familias) do |familia|
  json.extract! familia, :id, :padre_id, :integer,, :codfamilia, :string,, :describe, :string,, :componer_id, :integer,, :propia, :bool,, :competencia, :bool,orden, :integer
  json.url familia_url(familia, format: :json)
end
