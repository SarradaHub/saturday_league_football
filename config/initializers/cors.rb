# frozen_string_literal: true

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins [
      'http://127.0.0.1:5173',
      'http://127.0.0.1:5174',
      'http://localhost:5173', # Vite default port
      'http://localhost:5174', # Vite alternate port
      'http://localhost:8080', # API Gateway
      'https://saturday-league-football-frontend.vercel.app' # Your production domain
    ]
    resource '/api/v1/*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             max_age: 600
  end
end
