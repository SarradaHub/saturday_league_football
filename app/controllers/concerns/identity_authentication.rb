module IdentityAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user, if: :requires_authentication?
  end

  private

  def authenticate_user
    token = extract_token_from_header
    return render_unauthorized unless token

    result = IdentityServiceClient.validate_token(token)
    
    if result[:valid]
      @current_user = result[:user]
    else
      render_unauthorized
    end
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header

    parts = auth_header.split(" ")
    parts[1] if parts.length == 2 && parts[0] == "Bearer"
  end

  def render_unauthorized
    render json: {
      success: false,
      message: "Unauthorized",
      code: "UNAUTHORIZED"
    }, status: :unauthorized
  end

  def requires_authentication?
    true # Override in controllers that don't need auth
  end

  def current_user
    @current_user
  end
end

