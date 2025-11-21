require "faraday"
require "json"

module IdentityServiceClient
  class << self
    def validate_token(token)
      return { valid: false, error: "Token required" } if token.blank?

      identity_service_url = identity_service_base_url
      return { valid: false, error: "Identity service not configured" } if identity_service_url.blank?

      response = CircuitBreakerService.call_service(
        "identity-service",
        method: :post,
        path: "/api/v1/auth/validate",
        params: { token: token },
        headers: { "Content-Type" => "application/json" }
      )

      if response[:success] && response[:data]["success"]
        {
          valid: true,
          user: response[:data]["data"]["user"]
        }
      else
        { valid: false, error: response[:error] || "Token validation failed" }
      end
    rescue => e
      Rails.logger.error "Identity service validation error: #{e.message}"
      { valid: false, error: e.message }
    end

    def get_user(user_id)
      identity_service_url = identity_service_base_url
      return nil if identity_service_url.blank?

      response = CircuitBreakerService.call_service(
        "identity-service",
        method: :get,
        path: "/api/v1/users/#{user_id}",
        headers: { "Authorization" => "Bearer #{service_api_key}" }
      )

      response[:success] ? response[:data]["data"] : nil
    rescue => e
      Rails.logger.error "Identity service get_user error: #{e.message}"
      nil
    end

    private

    def identity_service_base_url
      ENV.fetch("IDENTITY_SERVICE_URL", "http://identity-service:3001")
    end

    def service_api_key
      ENV.fetch("SERVICE_API_KEY", "")
    end
  end
end

