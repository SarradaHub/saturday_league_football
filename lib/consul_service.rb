require "diplomat"

module ConsulService
  class << self
    def register_service
      return unless consul_enabled?

      service_name = "saturday-league-api"
      service_port = ENV.fetch("PORT", "3000").to_i
      consul_url = ENV.fetch("CONSUL_URL", "http://localhost:8500")

      Diplomat.configure do |config|
        config.url = consul_url
      end

      service_definition = {
        ID: service_name,
        Name: service_name,
        Tags: ["rails", "api", "v1"],
        Address: service_address,
        Port: service_port,
        Check: {
          HTTP: "http://#{service_address}:#{service_port}/health",
          Interval: "10s",
          Timeout: "5s",
          DeregisterCriticalServiceAfter: "30s"
        }
      }

      Diplomat::Service.register(service_definition)
      Rails.logger.info "Registered #{service_name} with Consul at #{consul_url}"
    rescue => e
      Rails.logger.error "Failed to register with Consul: #{e.message}"
    end

    def deregister_service
      return unless consul_enabled?

      Diplomat::Service.deregister("saturday-league-api")
      Rails.logger.info "Deregistered saturday-league-api from Consul"
    rescue => e
      Rails.logger.error "Failed to deregister from Consul: #{e.message}"
    end

    def discover_service(service_name)
      return nil unless consul_enabled?

      services = Diplomat::Service.get(service_name, :all)
      return nil if services.empty?

      # Return first healthy service
      service = services.find { |s| s[:Status] == "passing" } || services.first
      "http://#{service[:Address]}:#{service[:Port]}"
    rescue => e
      Rails.logger.error "Failed to discover service #{service_name}: #{e.message}"
      nil
    end

    private

    def consul_enabled?
      ENV.fetch("CONSUL_ENABLED", "false") == "true"
    end

    def service_address
      ENV.fetch("SERVICE_ADDRESS", "localhost")
    end
  end
end

