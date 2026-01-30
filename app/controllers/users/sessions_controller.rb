# frozen_string_literal: true

module Users
  class SessionsController < ApplicationController
    respond_to :json

    # POST /users/sign_in
    def create
      email = params[:user]&.dig(:email)
      password = params[:user]&.dig(:password)

      Rails.logger.info "Login attempt for: #{email}"

      # Find user by email
      user = User.find_by(email: email)

      if user && user.valid_password?(password)
        # For API-only apps, we don't use sessions
        # Just return a token that the client can use for subsequent requests
        render json: {
          success: true,
          message: 'Signed in successfully',
          user: {
            id: user.id,
            email: user.email
            # Adicione outros campos do usuário conforme necessário
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

    # DELETE /users/sign_out
    def destroy
      # For API-only apps, logout is handled client-side by removing the token
      # No server-side session to clear
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
      # Se você estiver usando JWT ou outro sistema de tokens
      # Aqui você pode gerar um token JWT ou retornar um token do Devise
      # Por enquanto, vamos usar um token simples baseado no email e timestamp
      # Você pode substituir isso por JWT ou outro sistema de tokens

      # Exemplo com JWT (se você tiver a gem jwt instalada):
      # JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secrets.secret_key_base)

      # Por enquanto, vamos retornar um token simples
      # Em produção, você deve usar um sistema de tokens mais seguro
      # Use strict_encode64 para evitar quebras de linha
      Base64.strict_encode64("#{user.id}:#{Time.current.to_i}")
    end
  end
end
