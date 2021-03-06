class FamiliasPropiedadesController < ApplicationController
  before_action :set_familia_propiedad, only: [:show, :edit, :update, :destroy]

  # GET /familias_propiedades
  # GET /familias_propiedades.json
  def index
    @familias_propiedades = FamiliaPropiedad.all
  end

  # GET /familias_propiedades/1
  # GET /familias_propiedades/1.json
  def show
    @fp=FamiliaPropiedad.find(params[:id])
    @k=flash[:success] ? :success : (flash[:danger] ? :danger : nil)  

    @valoresligados_elegibles=FamiliaPropiedad.connection.select_values("select valor,id from mod_propiedades_valoresligados_pdtes(#{@fp.id})")
    
    #@fp.familias_valoresligados.new
    @valoresligadospdtes=FamiliaPropiedad.connection.select_rows("select valor,id from mod_propiedades_valoresligados_pdtes (#{@fp.id})")
    #@valoresligadospdtes=@valoresligadospdtes[0]
  end

  # GET /familias_propiedades/new
  def new
    @familia_propiedad = FamiliaPropiedad.new
  end

  # GET /familias_propiedades/1/edit
  def edit
  end

  # POST /familias_propiedades
  # POST /familias_propiedades.json
  def create
    @familia_propiedad = FamiliaPropiedad.new(familia_propiedad_params)
    

    respond_to do |format|
      if @familia_propiedad.save
        format.html { redirect_to @familia_propiedad}
        format.json { render action: 'show', status: :created, location: @familia_propiedad }
      else
        
        format.html { render action: 'show' }
        format.json { render json: @familia_propiedad.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /familias_propiedades/1
  # PATCH/PUT /familias_propiedades/1.json
  def update
    ruta=params[:ruta]
    respond_to do |format|
      if @familia_propiedad.update(familia_propiedad_params)
        format.html { redirect_to @familia_propiedad ,:ruta => ruta, :flash => {:success => 'Valor/es  ligado correctamente guardado/Eliminado'} }
        format.json { head :no_content }
      else
        format.html { render action: @familia_propiedad,:ruta => params[:ruta],:flash => {:danger => 'Valor ligado No se pudo guardar'} }
        format.json { render json: @familia_propiedad.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /familias_propiedades/1
  # DELETE /familias_propiedades/1.json
  def destroy
    @familia_propiedad.destroy
    respond_to do |format|
      format.html { redirect_to familias_propiedades_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_familia_propiedad
      @familia_propiedad = FamiliaPropiedad.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def familia_propiedad_params
      params.require(:familia_propiedad).permit(familias_valoresligados_attributes: [:id, :fp_id,:fp2_id, :_destroy])
    end
end
