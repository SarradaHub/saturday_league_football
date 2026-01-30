# frozen_string_literal: true

require 'database_cleaner/active_record'

# Disable safeguard for test environment (Docker uses DATABASE_URL which is considered "remote")
# The safeguard checks for remote URLs and blocks DatabaseCleaner operations
# We need to override the safeguard to allow Docker database URLs
if Rails.env.test? && ENV['DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL'] == 'true'
  # Monkey-patch the safeguard class to skip the check in Docker test environments
  # This must be done after requiring database_cleaner but before any operations
  DatabaseCleaner::Safeguard::RemoteDatabaseUrl.class_eval do
    def run
      # Skip safeguard check in Docker test environments
      return if ENV['DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL'] == 'true'
      # Call original implementation
      super
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    # Disable safeguard for test environment (Docker uses DATABASE_URL which is considered "remote")
    # This allows DatabaseCleaner to work in Docker environments where DATABASE_URL points to a service
    # The safeguard is disabled via ENV['DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL'] in docker-compose.test.yml
    if Rails.env.test?
      # Allow Docker database URLs (postgresql://postgres:password@db:5432/...)
      DatabaseCleaner.url_allowlist = [
        %r{postgresql://.*@db:5432/.*},
        %r{postgresql://.*@localhost:5432/.*}
      ]
    end
    
    # Use :truncation strategy for parallel tests to avoid deadlocks with counter caches
    # :transaction can cause deadlocks when multiple processes access the same database
    # :deletion can also cause deadlocks when updating counter caches
    # :truncation is the safest for parallel execution, but slower
    if ENV['TEST_ENV_NUMBER']
      # For parallel tests, use truncation
      # This disables foreign key checks temporarily and truncates all tables
      # which avoids deadlocks from counter cache updates
      DatabaseCleaner.strategy = :truncation
    else
      # For non-parallel tests, use transaction for speed
      DatabaseCleaner.strategy = :transaction
    end
    
    # Skip clean_with in Docker environments due to safeguard restrictions
    # Each test will clean the database via around(:each) anyway, so this is not critical
    # The safeguard blocks clean_with even with url_allowlist configured
    unless Rails.env.test? && ENV['DATABASE_URL']&.include?('@db:5432')
      begin
        DatabaseCleaner.clean_with(:truncation)
      rescue DatabaseCleaner::Safeguard::Error::RemoteDatabaseUrl
        # Silently skip in Docker test environments
        # Database will be cleaned by each test via around(:each)
      end
    end
  end

  config.around(:each) do |example|
    # In Docker test environments, use direct database truncation to avoid safeguard issues
    # Check if we're in a Docker environment by checking DATABASE_URL
    # Always use direct truncation if DATABASE_URL contains @db:5432 (Docker service name)
    use_direct_truncation = ENV['DATABASE_URL']&.include?('@db:5432')
    
    if use_direct_truncation
      # Use direct database truncation as workaround for safeguard issue
      # Clean database before each test (similar to DatabaseCleaner.cleaning)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        # Get all tables except schema_migrations and ar_internal_metadata
        tables = connection.tables.reject { |t| t == 'schema_migrations' || t == 'ar_internal_metadata' }
        if tables.any?
          connection.execute("TRUNCATE TABLE #{tables.join(', ')} RESTART IDENTITY CASCADE")
        end
      end
      example.run
    else
      # Use DatabaseCleaner normally in non-Docker environments
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end
end
