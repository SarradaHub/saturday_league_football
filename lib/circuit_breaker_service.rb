require "circuitbox"
require "faraday"
require "faraday/retry"

module CircuitBreakerService
  class << self
    def create_client(service_name, base_url = nil)
      # Get service URL from Consul if not provided
      url = base_url || ConsulService.discover_service(service_name) || base_url
      
      return nil unless url

      circuit = Circuitbox.circuit(service_name.to_sym, {
        exceptions: [Faraday::Error, Timeout::Error],
        timeout: 5,
        sleep_window: 60,
        volume_threshold: 10,
        error_threshold: 50,
        time_window: 60
      })

      Faraday.new(url: url) do |conn|
        conn.request :retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [429, 500, 502, 503, 504]
        }
        conn.adapter Faraday.default_adapter
      end.tap do |client|
        client.builder.insert_before(Faraday::Adapter, Circuitbox::FaradayMiddleware, circuit: circuit)
      end
    end

    def call_service(service_name, method: :get, path: "", params: {}, headers: {})
      client = create_client(service_name)
      return { success: false, error: "Service unavailable" } unless client

      begin
        response = client.public_send(method, path, params, headers)
        { success: true, data: JSON.parse(response.body), status: response.status }
      rescue Circuitbox::OpenCircuitError => e
        Rails.logger.error "Circuit breaker open for #{service_name}: #{e.message}"
        { success: false, error: "Service temporarily unavailable", circuit_open: true }
      rescue => e
        Rails.logger.error "Error calling #{service_name}: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end

