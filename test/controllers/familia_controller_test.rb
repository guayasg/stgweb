require 'test_helper'

class FamiliaControllerTest < ActionController::TestCase
  setup do
    @familia = familia(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:familia)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create familia" do
    assert_difference('Familia.count') do
      post :create, familia: {  }
    end

    assert_redirected_to familia_path(assigns(:familia))
  end

  test "should show familia" do
    get :show, id: @familia
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @familia
    assert_response :success
  end

  test "should update familia" do
    patch :update, id: @familia, familia: {  }
    assert_redirected_to familia_path(assigns(:familia))
  end

  test "should destroy familia" do
    assert_difference('Familia.count', -1) do
      delete :destroy, id: @familia
    end

    assert_redirected_to familia_index_path
  end
end
