# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      resources :championships, defaults: { format: :json }
      resources :rounds, defaults: { format: :json }
      resources :matches, defaults: { format: :json }
      resources :teams, defaults: { format: :json }
      resources :players, defaults: { format: :json } do
        post 'add_to_round', on: :member
        post 'add_to_team', on: :member
      end

      resources :player_stats, defaults: { format: :json }

      match '*any', via: [:options], to: -> (_) { [204, { 'Content-Type' => 'text/plain' }, []] }
    end
  end
end
