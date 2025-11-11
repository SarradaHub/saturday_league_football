# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SaturdayLeagueFootball
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.api_only = true

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    domain_subdirectories = %w[services presenters queries serializers policies].map do |folder|
      Rails.root.join('app', folder).to_s
    end

    config.autoload_paths += domain_subdirectories
    config.eager_load_paths += domain_subdirectories

    config.generators do |g|
      g.test_framework :rspec,
                       request_specs: false,
                       view_specs: false,
                       routing_specs: false,
                       helper_specs: false,
                       controller_specs: true
    end
  end
end
