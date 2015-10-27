require 'test_helper'

class FamiliasPropiedadControllerTest < ActionController::TestCase
  setup do
    @familia_propiedad = familia_propiedad(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:familia_propiedad)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create familia_propiedad" do
    assert_difference('FamiliaPropiedad.count') do
      post :create, familia_propiedad: {  }
    end

    assert_redirected_to familia_propiedad_path(assigns(:familia_propiedad))
  end

  test "should show familia_propiedad" do
    get :show, id: @familia_propiedad
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @familia_propiedad
    assert_response :success
  end

  test "should update familia_propiedad" do
    patch :update, id: @familia_propiedad, familia_propiedad: {  }
    assert_redirected_to familia_propiedad_path(assigns(:familia_propiedad))
  end

  test "should destroy familia_propiedad" do
    assert_difference('FamiliaPropiedad.count', -1) do
      delete :destroy, id: @familia_propiedad
    end

    assert_redirected_to familias_propiedad_path
  end
end
