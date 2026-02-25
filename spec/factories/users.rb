# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    is_admin { false }
    sequence(:external_id) { |n| "user-#{n}" }

    trait :admin do
      sequence(:email) { |n| "admin#{n}@example.com" }
      is_admin { true }
      external_id { "admin" }
    end
  end
end
