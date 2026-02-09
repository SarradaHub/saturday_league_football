# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

# Enable gzip compression for responses
use Rack::Deflater

run Rails.application
Rails.application.load_server
