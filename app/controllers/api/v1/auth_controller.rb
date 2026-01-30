# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      def me
        render json: {
          success: true,
          user: serialize_user(current_user)
        }
      end

      def validate
        render json: {
          success: true,
          user: serialize_user(current_user)
        }
      end

      private

      def serialize_user(user)
        return nil unless user

        {
          id: user.id,
          email: user.email
        }
      end
    end
  end
end
