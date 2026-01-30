# frozen_string_literal: true

module Users
  class SyncFromIdentityService < ApplicationService
    def initialize(identity_user_data)
      @identity_user_data = identity_user_data
    end

    def call
      return nil unless identity_user_data.present?

      external_id = identity_user_data['id'] || identity_user_data[:id]
      return nil unless external_id.present?

      user = User.find_or_initialize_by(external_id: external_id.to_s)

      # Update user attributes from IdentityService
      user.email = identity_user_data['email'] || identity_user_data[:email] || user.email
      user.is_admin = extract_admin_flag(identity_user_data)
    if user.new_record?
      password = SecureRandom.hex(16)
      user.password = password
      user.password_confirmation = password
    end

      # Save user (will create or update)
      user.save! if user.changed?

      user
    rescue => e
      Rails.logger.error "Error syncing user from IdentityService: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    private

    attr_reader :identity_user_data

    def extract_admin_flag(data)
      # Try different possible fields for admin flag
      return true if data['is_admin'] == true || data[:is_admin] == true
      return true if data['role'] == 'admin' || data[:role] == 'admin'
      return true if data['roles']&.include?('admin') || data[:roles]&.include?('admin')

      false
    end
  end
end
