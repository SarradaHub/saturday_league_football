class HealthController < ApplicationController
  def health
    render json: {
      status: 'ok',
      service: 'saturday-league-api',
      timestamp: Time.current.iso8601,
      environment: Rails.env
    }, status: :ok
  end

  def ready
    # Check database connection
    ActiveRecord::Base.connection.execute('SELECT 1')

    render json: {
      status: 'ready',
      service: 'saturday-league-api',
      timestamp: Time.current.iso8601
    }, status: :ok
  rescue => e
    render json: {
      status: 'not ready',
      service: 'saturday-league-api',
      error: "Database connection failed: #{e.message}"
    }, status: :service_unavailable
  end
end
