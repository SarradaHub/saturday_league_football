# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ScatteredSetup, RSpec/ExampleLength

RSpec.describe HealthController, type: :controller do
  let(:json_response) { JSON.parse(response.body) }

  def perform_get(action)
    get action, format: :json
  end

  describe '#health' do
    before { perform_get(:health) }

    it 'returns ok status with service information' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns service metadata' do
      expect(json_response).to include(
        'status' => 'ok',
        'service' => 'saturday-league-api'
      )
    end

    it 'returns timestamp and environment' do
      expect(json_response).to have_key('timestamp')
      expect(json_response).to have_key('environment')
    end

    it 'returns current environment' do
      expect(json_response['environment']).to eq(Rails.env)
    end

    it 'returns timestamp in ISO8601 format' do
      perform_get(:health)
      expect(response).to have_http_status(:ok)
      expect { Time.iso8601(json_response['timestamp']) }.not_to raise_error
    end

    it 'returns a recent timestamp' do
      perform_get(:health)
      timestamp = Time.iso8601(json_response['timestamp'])
      expect(timestamp).to be_within(5.seconds).of(Time.current)
    end

    it 'returns correct environment' do
      perform_get(:health)
      expect(response).to have_http_status(:ok)
      expect(json_response['environment']).to be_in(['test', 'development'])
    end
  end

  describe '#ready' do
    context 'when database is connected' do
      before { perform_get(:ready) }

      it 'returns ready status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns service metadata' do
        expect(json_response).to include(
          'status' => 'ready',
          'service' => 'saturday-league-api'
        )
      end

      it 'returns timestamp' do
        expect(json_response).to have_key('timestamp')
      end
    end

    context 'when database connection fails' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('Connection failed'))
perform_get(:ready)
      end


      it 'returns not ready status' do
        expect(response).to have_http_status(:service_unavailable)
      end

      it 'returns service metadata' do
        expect(json_response).to include(
          'status' => 'not ready',
          'service' => 'saturday-league-api'
        )
      end

      it 'includes database error message' do
        expect(json_response['error']).to include('Database connection failed')
      end

      it 'includes error message in response' do
        perform_get(:ready)
        expect(response).to have_http_status(:service_unavailable)
        expect(json_response['error']).to be_a(String)
        expect(json_response['error']).to include('Connection failed')
      end
    end

    context 'when database connection fails with different error types' do
      it 'handles PG::ConnectionBad errors' do
        error = Class.new(StandardError).new('PG::ConnectionBad')
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(error)

        perform_get(:ready)
        expect(response).to have_http_status(:service_unavailable)
        expect(json_response['status']).to eq('not ready')
        expect(json_response['error']).to include('Database connection failed')
      end

      it 'handles timeout errors' do
        error = Timeout::Error.new('Connection timeout')
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(error)

        perform_get(:ready)
        expect(response).to have_http_status(:service_unavailable)
        expect(json_response['status']).to eq('not ready')
        expect(json_response['error']).to include('Connection timeout')
      end
    end

    it 'returns timestamp in ISO8601 format when ready' do
      perform_get(:ready)
      expect(response).to have_http_status(:ok)
      expect { Time.iso8601(json_response['timestamp']) }.not_to raise_error
    end

    it 'returns recent timestamp when ready' do
      perform_get(:ready)
      timestamp = Time.iso8601(json_response['timestamp'])
      expect(timestamp).to be_within(5.seconds).of(Time.current)
    end

    it 'returns error message when not ready' do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('Connection failed'))

      perform_get(:ready)
      expect(response).to have_http_status(:service_unavailable)
    end

    it 'includes error response fields when not ready' do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('Connection failed'))
      perform_get(:ready)
      expect(json_response).to have_key('error')
      expect(json_response['status']).to eq('not ready')
    end
  end
end

# rubocop:enable RSpec/ScatteredSetup, RSpec/ExampleLength
