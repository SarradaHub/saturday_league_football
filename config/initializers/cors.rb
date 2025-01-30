# frozen_string_literal: true

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins [
      'http://localhost:5173', # Vite default port
      'https://saturday-league-football-frontend.vercel.app' # Your production domain
    ]
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head]
  end
end
