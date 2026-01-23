# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe '#health' do
    it 'returns ok status with service information' do
      get :health, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to include(
        'status' => 'ok',
        'service' => 'saturday-league-api'
      )
      expect(json_response).to have_key('timestamp')
      expect(json_response).to have_key('environment')
      expect(json_response['environment']).to eq(Rails.env)
    end

    it 'returns timestamp in ISO8601 format' do
      get :health, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Verify timestamp is valid ISO8601 format
      expect { Time.iso8601(json_response['timestamp']) }.not_to raise_error
      timestamp = Time.iso8601(json_response['timestamp'])
      expect(timestamp).to be_within(5.seconds).of(Time.current)
    end

    it 'returns correct environment' do
      get :health, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Environment can be 'test' or 'development' depending on how tests are run
      expect(json_response['environment']).to be_in(['test', 'development'])
    end
  end

  describe '#ready' do
    context 'when database is connected' do
      it 'returns ready status' do
        get :ready, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to include(
          'status' => 'ready',
          'service' => 'saturday-league-api'
        )
        expect(json_response).to have_key('timestamp')
      end
    end

    context 'when database connection fails' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('Connection failed'))
      end

      it 'returns not ready status' do
        get :ready, format: :json
        
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to include(
          'status' => 'not ready',
          'service' => 'saturday-league-api'
        )
        expect(json_response['error']).to include('Database connection failed')
      end

      it 'includes error message in response' do
        get :ready, format: :json
        
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to be_a(String)
        expect(json_response['error']).to include('Connection failed')
      end
    end

    context 'when database connection fails with different error types' do
      it 'handles PG::ConnectionBad errors' do
        error = Class.new(StandardError).new('PG::ConnectionBad')
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(error)
        
        get :ready, format: :json
        
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('not ready')
        expect(json_response['error']).to include('Database connection failed')
      end

      it 'handles timeout errors' do
        error = Timeout::Error.new('Connection timeout')
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(error)
        
        get :ready, format: :json
        
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('not ready')
        expect(json_response['error']).to include('Connection timeout')
      end
    end

    it 'returns timestamp in ISO8601 format when ready' do
      get :ready, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Verify timestamp is valid ISO8601 format
      expect { Time.iso8601(json_response['timestamp']) }.not_to raise_error
      timestamp = Time.iso8601(json_response['timestamp'])
      expect(timestamp).to be_within(5.seconds).of(Time.current)
    end

    it 'returns error message when not ready' do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('Connection failed'))
      
      get :ready, format: :json
      
      expect(response).to have_http_status(:service_unavailable)
      json_response = JSON.parse(response.body)
      
      # Error response may or may not include timestamp depending on implementation
      expect(json_response).to have_key('error')
      expect(json_response['status']).to eq('not ready')
    end
  end
end
