require 'resque/server'
Mpdx::Application.routes.draw do

  resources :account_lists, only: :update

  resources :mail_chimp_accounts do
    collection do
      get :sync
    end
  end

  get "settings/integrations", as: :integrations_settings

  resources :tags, only: [:create, :destroy]

  resources :social_streams, only: :index

  namespace :api do
    api_version(module: "V1", header: "API-VERSION", value: "v1", parameter: "version", path: 'v1') do
      resources :contacts
      resources :people
      resources :addresses
      resources :email_addresses
      resources :phone_numbers
      resources :tasks
      resources :preferences
      resources :users
    end
  end

  resources :imports

  resources :activity_comments

  resources :donations, only: :index
  resources :accounts
  resources :preferences

  resources :contacts do
    collection do
      get :social_search
      post :bulk_update
      post :merge
      get  :find_duplicates
    end
    member do
      get :add_referrals
      post :save_referrals
    end
    resources :people
  end

  resources :tasks do
    collection do
      get :starred
      get :completed
      get :history
    end
  end
  resources :people 
  resources :setup

  namespace :person do
    resources :organization_accounts
  end

  get "home/index"
  get "privacy" => "home#privacy"
  get "home/change_account_list"
  get "home/download_data_check"
  get "login" => "home#login"

  devise_for :users
  as :user do
    get "/logout" => "devise/sessions#destroy"
  end


  match 'monitors/lb' => 'monitors#lb'

  # The priority is based upon order of creation:
  # first created -> highest priority.


  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  match '/auth/:provider/callback', to: 'accounts#create'
  match '/auth/failure', to: 'accounts#failure'

  mount Resque::Server.new, :at => "/resque"

  root :to => 'home#index'

  # See how all your routes lay out with "rake routes"

end
