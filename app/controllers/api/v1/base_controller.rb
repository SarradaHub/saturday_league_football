# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include IdentityAuthentication

      protect_from_forgery with: :null_session
      respond_to :json

      private

      def requires_authentication?
        true
      end
    end
  end
end

