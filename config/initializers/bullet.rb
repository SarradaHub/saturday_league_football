# frozen_string_literal: true

if defined?(Bullet)
  Bullet.enable = Rails.env.development? || Rails.env.test?
  Bullet.bullet_logger = false
  Bullet.rails_logger = true
  Bullet.add_footer = false
end
