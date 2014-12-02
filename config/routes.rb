require 'sidekiq/web'
Rails.application.routes.draw do

  resources :google_integrations, only: [:show, :edit, :update, :create] do
    member do
      get :sync
    end
  end

  resources :help_requests

  get '/help' => 'help_requests#new'

  resources :notifications

  resources :account_lists, only: :update

  resources :mail_chimp_accounts do
    collection do
      get :sync
    end
  end

  resources :prayer_letters_accounts do
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
          get :count
          get :tags
        end
      end
      resources :tasks do
        collection do
          get :count
        end
      end
      resources :donations, only: [:index]
      resources :preferences
      resources :users
      resources :appeals
    end
    match '*all' => 'v1/base#cors_preflight_check', via: 'OPTIONS'
  end

  resources :imports

  resources :activity_comments

  resources :donations
  resources :accounts
  resources :preferences do
    collection do
      post :update_tab_order
    end
  end

  resources :reports, only: [] do
    collection do
      get :contributions
    end
  end

  resources :contacts do
    collection do
      get :social_search
      put :bulk_update
      delete :bulk_destroy
      post :merge
      get  :find_duplicates
      put :not_duplicates
    end
    member do
      get :add_referrals
      post :save_referrals
      get :details
      get :referrals
    end
    resources :people do
      collection do
        post :merge
      end
    end
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

  resources :research, only: [:index] do
    member do
      get :search
    end
  end

  resources :setup

  namespace :person do
    resources :organization_accounts, only: [:new, :create, :edit, :update, :destroy]
  end

  resource :home, only: [:index], controller: :home do
    get "index"
    get "connect"
    get "care"
    get "cultivate"
    get "progress"
    get "change_account_list"
    get "download_data_check"
  end

  get "privacy" => "home#privacy"
  get "login" => "home#login"

  devise_for :users
  as :user do
    get "/logout" => "sessions#destroy"
  end


  get 'monitors/lb' => 'monitors#lb'

  get '/auth/prayer_letters/callback', to: 'prayer_letters_accounts#create'
  get '/auth/:provider/callback', to: 'accounts#create'
  get '/auth/failure', to: 'accounts#failure'

  developer_user_constraint = lambda { |request| request.env["rack.session"] and
                                  request.env["rack.session"]["warden.user.user.key"] and
                                  request.env["rack.session"]["warden.user.user.key"][0] and
                                  User.find(request.env["rack.session"]["warden.user.user.key"][0].first).developer }
  constraints developer_user_constraint do
    mount Sidekiq::Web => '/sidekiq'
  end

  get '/404', :to => "errors#error_404"
  get '/500', :to => "errors#error_500"

  get '/mobile', to: redirect(subdomain: 'm', path: '/')

  mount Peek::Railtie => '/peek'
  root :to => 'home#index'

  get '/templates/:path.html' => 'templates#template', :constraints => { :path => /.+/  }

  # See how all your routes lay out with "rake routes"

end
