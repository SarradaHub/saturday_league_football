# frozen_string_literal: true

module IdentityAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user, if: :requires_authentication?
  end

  private

  def authenticate_user
    Rails.logger.info "=== AUTHENTICATE_USER CALLED ==="
    Rails.logger.info "Request path: #{request.path}"
    Rails.logger.info "Request headers keys: #{request.headers.to_h.keys.grep(/auth/i).inspect}"
    Rails.logger.info "Authorization header value: #{request.headers['Authorization']}"
    token = extract_token_from_header
    Rails.logger.info "Token extracted: #{token.present? ? 'present' : 'missing'}"
    return render_unauthorized unless token

    # Try to validate token locally first (for simple Base64 tokens from Devise login)
    local_user = validate_local_token(token)
    if local_user
      Rails.logger.info "Local token validated successfully for user: #{local_user.id}"
      @current_user = local_user
      return
    end

    Rails.logger.debug "Local token validation failed, trying IdentityService"

    # If local validation fails, try IdentityService
    result = IdentityServiceClient.validate_token(token)
    return render_unauthorized unless result

    if result[:valid]
      # Sync user from IdentityService to local User model
      identity_user_data = result[:user]
      local_user = Users::SyncFromIdentityService.call(identity_user_data)

      if local_user
        Rails.logger.info "IdentityService token validated successfully for user: #{local_user.id}"
        @current_user = local_user
      else
        Rails.logger.error "Failed to sync user from IdentityService"
        render_unauthorized
      end
    else
      Rails.logger.error "Token validation failed: #{result[:error]}"
      render_unauthorized
    end
  end

  def validate_local_token(token)
    # Try to decode the Base64 token (format: "user_id:timestamp")
    begin
      # Use strict_decode64 to handle tokens encoded with strict_encode64
      decoded = Base64.strict_decode64(token)
      Rails.logger.debug "Decoded token: #{decoded}"
      user_id, _timestamp = decoded.split(':')
      return nil unless user_id.present?

      user = User.find_by(id: user_id.to_i)
      Rails.logger.debug "User found: #{user.present? ? "yes (id: #{user.id})" : 'no'}"
      user
    rescue ArgumentError => e
      # Try regular decode64 as fallback (in case token has newlines)
      begin
        decoded = Base64.decode64(token).strip
        Rails.logger.debug "Decoded token (fallback): #{decoded}"
        user_id, _timestamp = decoded.split(':')
        return nil unless user_id.present?

        user = User.find_by(id: user_id.to_i)
        Rails.logger.debug "User found (fallback): #{user.present? ? "yes (id: #{user.id})" : 'no'}"
        user
      rescue => e2
        Rails.logger.debug "Local token validation failed: #{e2.class} - #{e2.message}"
        nil
      end
    rescue => e
      Rails.logger.debug "Local token validation failed: #{e.class} - #{e.message}"
      Rails.logger.debug e.backtrace.first(3).join("\n")
      nil
    end
  end

  def extract_token_from_header
    auth_header = request.headers['Authorization']
    Rails.logger.debug "Authorization header: #{auth_header.present? ? 'present' : 'missing'}"
    return nil unless auth_header

    parts = auth_header.split(' ')
    token = parts[1] if parts.length == 2 && parts[0] == 'Bearer'
    Rails.logger.debug "Token extracted from header: #{token.present? ? 'yes' : 'no'}"
    token
  end

  def render_unauthorized
    render json: {
      success: false,
      message: 'Unauthorized',
      code: 'UNAUTHORIZED'
    }, status: :unauthorized
  end

  def requires_authentication?
    result = true # Override in controllers that don't need auth
    Rails.logger.info "requires_authentication? called, returning: #{result}"
    result
  end

  def current_user
    @current_user
  end
end
