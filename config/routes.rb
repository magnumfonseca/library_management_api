Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  devise_for :users,
             path: "api/v1",
             path_names: {
               sign_in: "login",
               sign_out: "logout",
               registration: "signup"
             },
             controllers: {
               sessions: "api/v1/sessions",
               registrations: "api/v1/registrations"
             }

  namespace :api do
    namespace :v1 do
      # Authenticated invitation management (RESTful routes with numeric IDs)
      resources :invitations, only: [ :index, :show, :create, :destroy ], constraints: { id: /\d+/ }

      # Public token-based invitation routes (unauthenticated)
      # These routes are intentionally separate to handle token-based access without authentication
      scope :invitations, as: :invitation do
        get "token/:token", to: "invitations#show_by_token", as: :by_token
        patch "token/:token/accept", to: "invitations#accept", as: :accept_by_token
      end

      resources :books

      resources :borrowings, only: [ :create, :index, :show ] do
        member do
          patch :return
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
