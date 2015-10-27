module ModForms
  module GestionParams
    def update_all_modelo modelo, param
      #Guarda (actualiza) todos los elementos de un modelo (usuarios, articulos....) pasados en 'modelo', y almacenadoos en el hash param
      #devolverá elementos del modelo no salvado (para gestionar errores)
      notsave=[]
      p2=param.dup
      p2.each do |k,v| # por cada parámetro
          @fp=modelo.find(v["id"].to_i) 
          if ['t', '1', 'true'].include? v['_destroy']
            @fp.destroy
          else
            p2.extract! :_destroy
            notsave.push(@fp) if !@fp.update_attributes(v)
          end 
      end
      notsave   
    end
  end
  
end