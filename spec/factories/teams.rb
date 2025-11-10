# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    name { Faker::Sports::Football.team }

    trait :with_round do
      round { FactoryBot.create(:round, :with_championship) }
    end
  end
end
