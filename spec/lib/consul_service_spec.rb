require 'rails_helper'

RSpec.describe ConsulService do
  describe '.register_service' do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CONSUL_ENABLED', 'false').and_return('true')
      allow(ENV).to receive(:fetch).with('PORT', '3000').and_return('3000')
      allow(ENV).to receive(:fetch).with('CONSUL_URL', 'http://localhost:8500').and_return('http://consul:8500')

      allow(Diplomat).to receive(:configure).and_yield(double('config', url: nil).as_null_object)
      allow(Diplomat::Service).to receive(:register)
      allow(Rails.logger).to receive(:info)
    end

    it 'registers the service when consul is enabled' do
      described_class.register_service

      expect(Diplomat::Service).to have_received(:register).once
    end
  end

  describe '.deregister_service' do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CONSUL_ENABLED', 'false').and_return('true')
      allow(Diplomat::Service).to receive(:deregister)
      allow(Rails.logger).to receive(:info)
    end

    it 'deregisters the service when consul is enabled' do
      described_class.deregister_service

      expect(Diplomat::Service).to have_received(:deregister).with('saturday-league-api')
    end
  end

  describe '.discover_service' do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CONSUL_ENABLED', 'false').and_return('true')
    end

    it 'returns nil when no services are found' do
      allow(Diplomat::Service).to receive(:get).and_return([])

      result = described_class.discover_service('unknown-service')

      expect(result).to be_nil
    end

    it 'returns the URL of the first passing service' do
      services = [
        { Status: 'passing', Address: '10.0.0.1', Port: 4000 },
        { Status: 'critical', Address: '10.0.0.2', Port: 4001 }
      ]
      allow(Diplomat::Service).to receive(:get).and_return(services)

      result = described_class.discover_service('test-service')

      expect(result).to eq('http://10.0.0.1:4000')
    end

    it 'falls back to the first service when none are passing' do
      services = [
        { Status: 'critical', Address: '10.0.0.1', Port: 4000 }
      ]
      allow(Diplomat::Service).to receive(:get).and_return(services)

      result = described_class.discover_service('test-service')

      expect(result).to eq('http://10.0.0.1:4000')
    end
  end
end

