require 'rails_helper'

RSpec.describe IdentityServiceClient do
  describe '.validate_token' do
    it 'returns invalid when token is blank' do
      result = described_class.validate_token(nil)

      expect(result[:valid]).to be(false)
      expect(result[:error]).to eq('Token required')
    end

    it 'returns invalid when identity service URL is not configured' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('IDENTITY_SERVICE_URL', 'http://identity-service:3001').and_return('')

      result = described_class.validate_token('token')

      expect(result[:valid]).to be(false)
      expect(result[:error]).to eq('Identity service not configured')
    end

    # rubocop:disable RSpec/ExampleLength
    it 'returns valid when CircuitBreakerService returns success and data' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('IDENTITY_SERVICE_URL', 'http://identity-service:3001')
                                   .and_return('http://identity-service:3001')

      response = {
        success: true,
        data: {
          'success' => true,
          'data' => {
            'user' => { 'id' => 1, 'email' => 'user@example.com' }
          }
        }
      }

      allow(CircuitBreakerService).to receive(:call_service).and_return(response)

      result = described_class.validate_token('valid-token')

      expect(result[:valid]).to be(true)
      expect(result[:user]).to eq({ 'id' => 1, 'email' => 'user@example.com' })
    end
    # rubocop:enable RSpec/ExampleLength

    # rubocop:disable RSpec/ExampleLength
    it 'returns invalid when CircuitBreakerService reports failure' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('IDENTITY_SERVICE_URL', 'http://identity-service:3001')
                                   .and_return('http://identity-service:3001')

      response = {
        success: false,
        error: 'Token validation failed'
      }

      allow(CircuitBreakerService).to receive(:call_service).and_return(response)

      result = described_class.validate_token('invalid-token')

      expect(result[:valid]).to be(false)
      expect(result[:error]).to eq('Token validation failed')
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe '.get_user' do
    it 'returns nil when identity service URL is not configured' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('IDENTITY_SERVICE_URL', 'http://identity-service:3001').and_return('')

      result = described_class.get_user(1)

      expect(result).to be_nil
    end

    # rubocop:disable RSpec/ExampleLength
    it 'returns user data when CircuitBreakerService returns success' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('IDENTITY_SERVICE_URL', 'http://identity-service:3001')
                                   .and_return('http://identity-service:3001')
      allow(ENV).to receive(:fetch).with('SERVICE_API_KEY', '').and_return('api-key')

      response = {
        success: true,
        data: {
          'data' => { 'id' => 1, 'email' => 'user@example.com' }
        }
      }

      allow(CircuitBreakerService).to receive(:call_service).and_return(response)

      result = described_class.get_user(1)

      expect(result).to eq({ 'id' => 1, 'email' => 'user@example.com' })
    end
    # rubocop:enable RSpec/ExampleLength

    # rubocop:disable RSpec/ExampleLength
    it 'returns nil when CircuitBreakerService reports failure' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('IDENTITY_SERVICE_URL', 'http://identity-service:3001')
                                   .and_return('http://identity-service:3001')
      allow(ENV).to receive(:fetch).with('SERVICE_API_KEY', '').and_return('api-key')

      response = {
        success: false,
        error: 'Service unavailable'
      }

      allow(CircuitBreakerService).to receive(:call_service).and_return(response)

      result = described_class.get_user(1)

      expect(result).to be_nil
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
