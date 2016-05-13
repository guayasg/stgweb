class FamiliasController < ApplicationController
  before_action :set_familia, only: [:show, :edit, :update, :destroy]
  #require "/lib/mod_forms/gestion_params" #gestión del hash params
  include GestionParams  
  include WillPaginate

  # GET /familias
  # GET /familias.json
  def familias_tree(id)
    @familias = Familia.find_by_sql("select * from menufamilias ") #menu de búsqueda
    @id=id
    
    @ruta=(@familias.select {|f| f.id==@id}).first.path if @id!=0
    @ruta||= "Top"   
  end
  
  
  def index
    familias_tree(params[:id].to_i)
    @familia_filtrada = @familias.select { |f| f.padre_id == (params[:id].to_i == 0 ? nil :params[:id].to_i) } # familias incluidas
    #@opciones=[['Seleccione Opcción',0],['Generar Todos los artículos',1],['Aplicar cambios a artículos seleccionados',2]]
    if @id != 0
      @k=flash[:success] ? :success : (flash[:danger] ? :danger : nil) # componemos la clave para mensajes de error
      @fam_prop = Familia.find(@id) # familias_propiedades
      @tienepropiedades = @fam_prop && @fam_prop.familias_propiedades.count >0
      #@nombres_articulos=Familia.find_by_sql("select * from mod_articulos_nombre(#{params[:id]},array[]::integer[],array[]::integer[],array[]::integer[]) ");
      #@nombres_articulos=Articulos.where(familia_id: @id)#Familia.connection.select_all("select * from mod_articulos_nombre(#{@id},array[]::integer[],array[]::integer[],array[]::integer[]) ")
      @propiedades_familia=Familia.connection.select_values("select propiedad_valor,id from mod_propiedades_elementos_combinatoria(#{@id})")
      @ 
    end
  end

  # GET /familias/1
  # GET /familias/1.json
  def show
     
  end

  # GET /familias/new
  def new
    familias_tree(params[:familia_id].to_i)
 
    if @id!=0
      @familia = Familia.new(:padre_id => @id )
    else
      @familia = Familia.new()
    end
  end

  # GET /familias/1/edit
  def edit
    #@familia=Familia.find(params[:id])
    familias_tree(params[:familia_id].to_i)
    @familia=Familia.find(@id) if @id!=0
    
  end
  
  def edit_familias_propiedades_desuso
        f_ids=[]
        params[:familia][:familias_propiedades_attributes].each do |k,v|
          #logger.debug " k =" + k.inspect + " v=" + v["id"]
          f_ids[k.to_i]=v["id"].to_i
        end
          
        @fp=FamiliaPropiedad.where(id: f_ids)
        familia_id=params[:familia][:familia_id].to_i
        #logger.debug "familia_id=" + familia_id.to_s
        
        notsave=[]
 
  if @fp
    @fp.each do |f| # por cada familiaPropiedad
          logger.debug "f_ids=" + f_ids.to_s + " f.id=" + f.id.to_s
          i=f_ids.index(f.id) #obtenemos el índice de f_ids en el que se encuentra el id en cuestión
          logger.debug "i=" + i.to_s
          #logger.debug "f.valor=" + params[:familia][:familias_propiedades_attributes][i][:valor] 
          if f.propiedad_id!=params[:familia][:familias_propiedades_attributes][i.to_s][:propiedad_id].to_i || 
              f.valor!=params[:familia][:familias_propiedades_attributes][i.to_s][:valor] 
            f.propiedad_id = params[:familia][:familias_propiedades_attributes][i.to_s][:propiedad_id].to_i
            f.valor=params[:familia][:familias_propiedades_attributes][i.to_s][:valor] 
            notsave.push(f) if !f.save
         end   
    end
   end
   index
        
        respond_to do |format|   
        if 1
          format.html { render action: 'index'  } 
          #format.html { redirect_to :action => :index, :q => @fp[0].familia_id  }
          format.json { head :no_content }
        else
          format.html { render action: 'edit' }
        end
      end

  end



def componer_articulo
  #se llama a la función de BD que compone los nombres de artículos
  i=params["subir"] || params["bajar"] # i contiene el artículo (id) a subir o bajr de orden
  id= params[:fp][i] if i #id contiene el id de familia o familia_propiedad que hay que ordenar (subir o bajar de orden)
  ordenar(i,id) if id
 #regenerar artículos
   @a=Familia.connection.select_values("select mod_propiedades_generar_grupos(#{params[:id]},0) as ret")
   k = (@a[0] && @a[0].slice(0,2)!='OK' ? :danger : :success) 
   flash[k] = @a[0].slice(0,500) # Si algún elmento queda repetido=>se informa (no se generan los artículos)
  
  
        respond_to do |format|   
          #format.html { render inline: "c= <%= @c %> <br> b= <%=  @b %>"  } 
          format.html { redirect_to  :action => :index, :id => params[:familia][:id]}
          format.json { head :no_content }
          format.html { render action: 'edit' }

      end
end

def edit_familias_propiedades
    notsave=[]
    
    FamiliaPropiedad.transaction do    
      notsave=update_all_modelo FamiliaPropiedad,params[:familia][:familias_propiedades_attributes] 
      if params[:new_cod]!="" &&  params[:new_prop]!="" && params[:new_valor]!="" && params[:new_separador]!=""
        FamiliaPropiedad.create(:familia_id => params[:familia][:id].to_i,:propiedad_id => params[:new_prop], :valor => params[:new_valor], :cod=> params[:new_cod],:separador=> params[:new_separador])
      end
      
    end 
        
        respond_to do |format|   
        if notsave.empty?
          #format.html { render action: :index, :id => @id }
          #format.html { render action: 'index'  } 
          format.html { redirect_to :action => :index, :id => params[:familia][:id], notice: "Valores Guardados"  }
          format.json { head :no_content }
        else
             #format.html { render action: :index, :id => params[:familia][:id] }
             notsave.each do |n|
               flash[:notice] = "Cod "  + n.cod + " " + n.errors.messages.values.flatten.to_s
             end
             format.html { redirect_to :action => :index, :id => params[:familia][:id]  }
        end
      end

  end


  # POST /familias
  # POST /familias.json
  def create
    @familia = Familia.new(familia_params)
    #@fp=@familia.familias_propiedades.new

    respond_to do |format|
      if @familia.save
        format.html { redirect_to :familias, :locals => {:id => @id}, notice: 'Familia was successfully created.' }
        format.json { render action: 'show', status: :created, location: @familia }
      else
        format.html { render action: 'new' }
        format.json { render json: @familia.errors, status: :unprocessable_entity }
      end
    end
  end




def create_familia_propiedad
    @familia = Familia.new(familia_params)
    #@fp=@familia.familias_propiedades.new

    respond_to do |format|
      if @familia.save
        format.html { redirect_to @familia, notice: 'Familia was successfully created.' }
        format.json { render action: 'show', status: :created, location: @familia }
      else
        format.html { render action: 'new' }
        format.json { render json: @familia.errors, status: :unprocessable_entity }
      end
    end
  end


  # PATCH/PUT /familias/1
  # PATCH/PUT /familias/1.json
  def update
    
    if params[:id]=="edit_familias_propiedades"
        edit_familias_propiedades
        return
     end
     
     #if params[:familia]["articulos_grupopropiedades_attributes"]
#        componer_articulo
#       return
     #end 
       
      respond_to do |format|
        if @familia.update(familia_params) 
          
          format.html { redirect_to familias_path(:id => @familia.padre_id), notice: 'Familia was successfully updated.' }
          format.json { head :no_content }
        else
          format.html { render action: 'edit' }
          format.json { render json: @familia.errors, status: :unprocessable_entity }
        end
      end
    
  end

  # DELETE /familias/1
  # DELETE /familias/1.json
  def destroy
    padre=@familia.padre_id
    @familia.destroy
    respond_to do |format|
      format.html { redirect_to familias_url(:id => padre) }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_familia
      
      @familia = Familia.find(params[:id]) if params[:id].to_i!=0 # si no es enterio=> no buscamos or id
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def familia_params
      params.require(:familia).permit(:padre_id, :codfamilia, :describe,  :componer_id,  :propia, :competencia, :orden, 
      familias_propiedades: [:propiedad_id, :valor])
    end
    
    def ordenar articulo_id,articulo_propiedad_id
      #llama a la función mod_articulos_orden_siguiente_anterior para obtener el elemento con el que intercambiar, y seguidamente a la función
      #mod_articulos_orden_propiedades
      
      if params.include?('subir')
         subir='subir'
         parametro_orden="[i2],[i1]"
      else
         subir= 'bajar'
         parametro_orden="[i1],[i2]"
      end
      
      @a=Familia.connection.select_values("select mod_articulos_orden_siguiente_anterior (#{params[:id]},#{articulo_id},#{articulo_propiedad_id},'#{subir}') as idintercambio")
      (parametro_orden.gsub! '[i1]',articulo_propiedad_id).gsub!('[i2]',@a[0])
      a=Familia.find_by_sql("select mod_articulos_orden_propiedades (#{parametro_orden})") 
      
    end
    
end
