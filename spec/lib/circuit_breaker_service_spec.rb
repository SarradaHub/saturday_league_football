require 'rails_helper'

RSpec.describe CircuitBreakerService do
  describe '.create_client' do
    let(:service_name) { 'test-service' }

    context 'when Consul returns a service URL' do
      before do
        allow(ConsulService).to receive(:discover_service).with(service_name).and_return('http://example.com')
      end

      it 'returns a Faraday client configured with retry middleware' do
        client = described_class.create_client(service_name)

        expect(client).to be_a(Faraday::Connection)
      end
    end

    context 'when Consul does not return a service URL' do
      before do
        allow(ConsulService).to receive(:discover_service).with(service_name).and_return(nil)
      end

      it 'returns nil' do
        expect(described_class.create_client(service_name)).to be_nil
      end
    end
  end

  describe '.call_service' do
    let(:service_name) { 'test-service' }
    let(:faraday_client) { instance_double(Faraday::Connection) }

    before do
      allow(described_class).to receive(:create_client).with(service_name).and_return(faraday_client)
    end

    # rubocop:disable RSpec/ExampleLength
    it 'returns success with parsed data when the call succeeds' do
      response = instance_double(Faraday::Response, body: '{"foo":"bar"}', status: 200)
      allow(faraday_client).to receive(:get).and_return(response)

      result = described_class.call_service(service_name, method: :get, path: '/test')

      expect(result[:success]).to be(true)
      expect(result[:data]).to eq({ 'foo' => 'bar' })
      expect(result[:status]).to eq(200)
    end
    # rubocop:enable RSpec/ExampleLength

    it 'handles open circuit errors gracefully' do
      allow(faraday_client).to receive(:get).and_raise(Circuitbox::OpenCircuitError.new('circuit open'))

      result = described_class.call_service(service_name, method: :get, path: '/test')

      expect(result[:success]).to be(false)
      expect(result[:circuit_open]).to be(true)
    end

    it 'handles generic errors gracefully' do
      allow(faraday_client).to receive(:get).and_raise(StandardError.new('boom'))

      result = described_class.call_service(service_name, method: :get, path: '/test')

      expect(result[:success]).to be(false)
      expect(result[:error]).to eq('boom')
    end
  end
end
