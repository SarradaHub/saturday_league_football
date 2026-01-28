# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ActionController::MimeResponds
    include ActionController::StrongParameters
    include IdentityAuthentication
  end
end
