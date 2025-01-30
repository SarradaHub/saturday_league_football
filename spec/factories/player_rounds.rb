# frozen_string_literal: true

FactoryBot.define do
  factory :player_round do
    trait :with_round do
      round { FactoryBot.create(:round) }
    end
    trait :with_player do
      player { FactoryBot.create(:player) }
    end
  end
end
