Rails.application.routes.draw do
  namespace :admin do
    get "login", to: "sessions#new", as: :login
    resource :session, only: %i[create destroy]
    resources :match_days, only: %i[index new create edit update]
    resources :seasons, except: :show
    resources :players, only: %i[index edit update] do
      member do
        patch :approve
        patch :reject
      end
    end
  end

  namespace :api do
    resources :vote_invites, only: :index
  end

  resources :players, only: :show
  resources :seasons, only: :show

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
