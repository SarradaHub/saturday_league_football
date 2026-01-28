# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    is_admin { false }
    external_id { SecureRandom.uuid }

    trait :admin do
      is_admin { true }
    end
  end
end
