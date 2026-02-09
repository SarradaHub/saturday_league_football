# frozen_string_literal: true

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV['CI'].present?

  config.public_file_server.headers = { 'cache-control' => 'public, max-age=3600' }

  config.consider_all_requests_local = true
  config.cache_store = :null_store

  config.action_dispatch.show_exceptions = :rescuable

  config.action_controller.allow_forgery_protection = false

  config.active_storage.service = :test

  config.action_mailer.delivery_method = :test

  config.action_mailer.default_url_options = { host: 'example.com' }

  config.active_support.deprecation = :stderr

  config.action_controller.raise_on_missing_callback_actions = false

  config.after_initialize do
    if defined?(Bullet)
      Bullet.enable = true
      Bullet.bullet_logger = false
      Bullet.rails_logger = true
      # Only raise on N+1 queries, not on "unused_eager_loading" warnings
      # "unused_eager_loading" is a performance suggestion, not a critical error
      # We'll handle this in spec/support/bullet.rb to only raise on N+1 queries
      Bullet.raise = true
    end
  end
end
