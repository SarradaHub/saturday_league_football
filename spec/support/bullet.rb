if defined?(Bullet)
  RSpec.configure do |config|
    config.before do
      Bullet.start_request
    end

    config.after do
      if Bullet.notification?
        # Intercept perform_out_of_channel_notifications to filter unused_eager_loading
        # Only raise on N+1 queries, not on "unused_eager_loading" warnings
        begin
          Bullet.perform_out_of_channel_notifications
        rescue Bullet::Notification::UnoptimizedQueryError => e
          # Check if it's an unused eager loading error
          if e.message.include?('AVOID eager loading') || e.message.include?('Remove from your query')
            # Log but don't fail for unused eager loading
            Rails.logger.warn("Bullet: Unused eager loading detected (not failing test): #{e.message}")
          else
            # Re-raise for N+1 queries and other critical issues
            raise e
          end
        end
      end
      Bullet.end_request
    end
  end
end
