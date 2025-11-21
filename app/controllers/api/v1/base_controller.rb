# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include IdentityAuthentication

      # CSRF protection is not needed for API controllers
      # APIs typically use token-based authentication instead
      respond_to :json

      private

      def requires_authentication?
        true
      end
    end
  end
end
