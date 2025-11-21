# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.3.6'

gem 'bootsnap', require: false
gem 'dotenv-rails'
gem 'foreman'
gem 'jbuilder'
gem 'kamal', require: false
gem 'pg', '~> 1.6'
gem 'propshaft'
gem 'puma', '>= 5.0'
gem 'rack-cors'
gem 'rails', '~> 8.1.1'
gem 'solid_cable'
gem 'solid_cache'
gem 'solid_queue'
gem 'stimulus-rails'
gem 'thruster', require: false
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[windows jruby]

# Microservices integration
gem 'diplomat' # Consul client
gem 'circuitbox' # Circuit breaker pattern
gem 'faraday' # HTTP client
gem 'faraday-retry' # HTTP retry logic

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails-omakase', require: false
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'

  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rails-controller-testing'
  gem 'rspec'
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-mocks'
  gem 'rspec-rails', '~> 8.0.2'
  gem 'simplecov'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
  gem 'bullet'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 7.0'
end
