# frozen_string_literal: true

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Standardized health check endpoints for microservices
  get 'health', to: 'health#health'
  get 'ready', to: 'health#ready'

  # Devise routes for User authentication
  devise_for :users, 
             skip: [:registrations, :passwords, :confirmations],
             controllers: {
               sessions: 'users/sessions'
             }

  namespace :api do
    namespace :v1 do
      get 'auth/me', to: 'auth#me'
      get 'auth/validate', to: 'auth#validate'
      post 'auth/validate', to: 'auth#validate'
      resources :championships, defaults: { format: :json }
      resources :rounds, defaults: { format: :json } do
        member do
          get :statistics
        end
      end
      resources :matches, defaults: { format: :json } do
        member do
          post :finalize
        end
      end
      resources :teams, defaults: { format: :json }
      resources :players, defaults: { format: :json } do
        post 'add_to_round', on: :member
        post 'add_to_team', on: :member
        get 'match_stats', on: :member
      end

      resources :player_stats, defaults: { format: :json } do
        get 'match/:match_id', action: :by_match, on: :collection
        post 'match/:match_id/bulk', action: :bulk_update, on: :collection
      end

      match '*any', via: :options, to: ->(_) { [204, { 'Content-Type' => 'text/plain' }, []] }
    end
  end
end
