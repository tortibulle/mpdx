require 'sidekiq/web'
Mpdx::Application.routes.draw do

  devise_for :admin_users, ActiveAdmin::Devise.config

  resources :help_requests

  #ActiveAdmin.routes(self)


  namespace :admin do
    resources :sessions do
      collection do
        get "failure"
        get "no_access"
      end
    end
  end

  resources :notifications

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
    api_version(module: 'V1', header: {name: 'API-VERSION', value: 'v1'}, parameter: {name: "version", value: 'v1'}, path: {value: 'v1'}) do
      resources :contacts do
        collection do
          get "pledge_frequencies"
        end
        resources :people
        resources :donations, only: :index
      end
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
      put :bulk_update
      post :merge
      get  :find_duplicates
    end
    member do
      get :add_referrals
      post :save_referrals
      get :details
    end
    resources :people
  end

  resources :tasks do
    collection do
      get :starred
      get :completed
      get :history
      delete :bulk_destroy
      put :bulk_update
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

  get "js" => "home#js"

  devise_for :users
  as :user do
    get "/logout" => "devise/sessions#destroy"
  end


  match 'monitors/lb' => 'monitors#lb'

  match '/auth/admin/callback', to: 'admin::sessions#create'
  match '/auth/:provider/callback', to: 'accounts#create'
  match '/auth/failure', to: 'accounts#failure'

  constraint = lambda { |request| request.env["rack.session"] and
                                  request.env["rack.session"]["warden.user.user.key"] and
                                  request.env["rack.session"]["warden.user.user.key"][0] and
                                  request.env["rack.session"]["warden.user.user.key"][1] and
                                  ['Starcher'].include?(request.env["rack.session"]["warden.user.user.key"][0].constantize.find(request.env["rack.session"]["warden.user.user.key"][1].first).last_name) }
  constraints constraint do
    mount Sidekiq::Web => '/sidekiq'
  end

  root :to => 'home#index'

  # See how all your routes lay out with "rake routes"

end
