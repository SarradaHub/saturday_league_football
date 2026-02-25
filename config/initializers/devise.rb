# frozen_string_literal: true

# Use this hook to configure devise mailer, warden hooks and so forth.
Devise.setup do |config|
  # ==> Mailer Configuration
  config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'

  # ==> ORM configuration
  require 'devise/orm/active_record'

  # ==> Configuration for any authentication mechanism
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # ==> Configuration for API-only applications
  # For API-only applications, http authentication should be enabled.
  config.http_authenticatable = [:database]

  # ==> Navigation configuration
  # Lists the formats that should be treated as navigational. For API mode, we set this to empty.
  config.navigational_formats = []

  # ==> Configuration for :database_authenticatable
  config.stretches = Rails.env.test? ? 1 : 12

  # ==> Configuration for :validatable
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # ==> Configuration for :rememberable
  config.expire_all_remember_me_on_sign_out = true

  # ==> Configuration for :recoverable
  config.reconfirmable = true

  # The default HTTP method used to sign out a resource is DELETE.
  config.sign_out_via = :delete
end
