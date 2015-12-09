Stgweb::Application.routes.draw do
  

  
  resources :entidades

  resources :familias do

    post 'componer_articulo', on: :collection
    post 'edit_familias_propiedades', on: :collection
    
    get 'mostrar_valores_ligados', on: :member
    post 'editar_valores_ligados', on: :member
    
    
  end
#    get 'familias_propiedades/:id', to: 'familias_propiedades#show', as: 'familias_propiedades'  
    #post 'familias/:id', to: 'familias#edit_familias_propiedades'
    post 'familias/:id', to: 'familias#componer_articulo'
    
    
    
  
  resources :familias_propiedades do
    resources :familias_valoresligados
    
  end  
  post 'familias_propiedades/:id', to: 'familias_propiedades#create'
  
  
  
  resources :propiedades
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
