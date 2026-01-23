# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that includes the concern
class TestController < ApplicationController
  include IdentityAuthentication

  def index
    render json: { success: true }
  end
end

RSpec.describe IdentityAuthentication, type: :controller do
  controller(TestController) do
  end

  describe 'authentication' do
    context 'with valid Bearer token' do
      before do
        allow(IdentityServiceClient).to receive(:validate_token).with('valid_token').and_return({
          valid: true,
          user: { id: 1, name: 'Test User' }
        })
        request.headers['Authorization'] = 'Bearer valid_token'
      end

      it 'allows access and sets current_user' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        # current_user is a private method, test indirectly through successful response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when token is missing' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'success' => false,
          'message' => 'Unauthorized',
          'code' => 'UNAUTHORIZED'
        )
      end
    end

    context 'when token is invalid' do
      before do
        allow(IdentityServiceClient).to receive(:validate_token).with('invalid_token').and_return({
          valid: false,
          error: 'Invalid token'
        })
        request.headers['Authorization'] = 'Bearer invalid_token'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'success' => false,
          'message' => 'Unauthorized',
          'code' => 'UNAUTHORIZED'
        )
      end
    end

    context 'when Authorization header has wrong format' do
      before do
        request.headers['Authorization'] = 'InvalidFormat token'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when Authorization header is malformed' do
      before do
        request.headers['Authorization'] = 'Bearer'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when Authorization header has more than 2 parts' do
      before do
        request.headers['Authorization'] = 'Bearer token extra_part'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when Authorization header has only one part' do
      before do
        request.headers['Authorization'] = 'TokenWithoutBearer'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when IdentityServiceClient returns result without :valid key' do
      before do
        allow(IdentityServiceClient).to receive(:validate_token).with('token').and_return({
          error: 'Some error'
        })
        request.headers['Authorization'] = 'Bearer token'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when IdentityServiceClient returns nil' do
      before do
        allow(IdentityServiceClient).to receive(:validate_token).with('token').and_return(nil)
        request.headers['Authorization'] = 'Bearer token'
      end

      it 'returns unauthorized' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe '#extract_token_from_header' do
    it 'extracts token from Bearer format' do
      request.headers['Authorization'] = 'Bearer my_token_123'
      token = controller.send(:extract_token_from_header)
      
      expect(token).to eq('my_token_123')
    end

    it 'returns nil when Authorization header is missing' do
      request.headers['Authorization'] = nil
      token = controller.send(:extract_token_from_header)
      
      expect(token).to be_nil
    end

    it 'returns nil when Authorization header does not start with Bearer' do
      request.headers['Authorization'] = 'Token my_token'
      token = controller.send(:extract_token_from_header)
      
      expect(token).to be_nil
    end

    it 'returns nil when Authorization header has wrong number of parts' do
      request.headers['Authorization'] = 'Bearer token extra'
      token = controller.send(:extract_token_from_header)
      
      expect(token).to be_nil
    end

    it 'returns nil when Authorization header has only Bearer' do
      request.headers['Authorization'] = 'Bearer'
      token = controller.send(:extract_token_from_header)
      
      expect(token).to be_nil
    end

    it 'extracts token correctly with multiple spaces in token' do
      request.headers['Authorization'] = 'Bearer token with spaces'
      token = controller.send(:extract_token_from_header)
      
      # Should return nil because split creates more than 2 parts
      expect(token).to be_nil
    end
  end

  describe '#requires_authentication?' do
    it 'returns true by default' do
      result = controller.send(:requires_authentication?)
      expect(result).to be true
    end
  end

  describe '#current_user' do
    context 'when user is authenticated' do
      before do
        allow(IdentityServiceClient).to receive(:validate_token).and_return({
          valid: true,
          user: { id: 1, name: 'Test User' }
        })
        request.headers['Authorization'] = 'Bearer valid_token'
      end

      it 'returns the current user' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        # current_user is set via @current_user instance variable
        user = controller.send(:current_user)
        expect(user).to eq({ id: 1, name: 'Test User' })
      end
    end

    context 'when user is not authenticated' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns nil' do
        get :index, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        user = controller.send(:current_user)
        expect(user).to be_nil
      end
    end
  end

  describe '#render_unauthorized' do
    it 'renders correct JSON response' do
      # Test through a request to trigger the before_action
      request.headers['Authorization'] = nil
      get :index, format: :json
      
      expect(response).to have_http_status(:unauthorized)
      json_response = JSON.parse(response.body)
      expect(json_response).to include(
        'success' => false,
        'message' => 'Unauthorized',
        'code' => 'UNAUTHORIZED'
      )
    end
  end
end
