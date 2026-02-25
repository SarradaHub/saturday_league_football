# frozen_string_literal: true

module Users
  class SessionsController < ApplicationController
    respond_to :json

    def create
      email = params[:user]&.dig(:email)
      password = params[:user]&.dig(:password)

      Rails.logger.info "Login attempt for: #{email}"

      user = User.find_by(email: email)

      if user && user.valid_password?(password)
        render json: {
          success: true,
          message: 'Signed in successfully',
          user: {
            id: user.id,
            email: user.email
          },
          token: generate_token(user)
        }, status: :ok
      else
        Rails.logger.error "Invalid credentials for: #{email}"
        render json: {
          success: false,
          message: 'Invalid email or password',
          error: 'INVALID_CREDENTIALS'
        }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "Login error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        message: 'Invalid email or password',
        error: 'INVALID_CREDENTIALS'
      }, status: :unauthorized
    end

    def destroy
      respond_to_on_destroy
    end

    private

    def respond_to_on_destroy
      respond_to do |format|
        format.json do
          render json: {
            success: true,
            message: 'Signed out successfully'
          }, status: :ok
        end
      end
    end

    def generate_token(user)
      Base64.strict_encode64("#{user.id}:#{Time.current.to_i}")
    end
  end
end
