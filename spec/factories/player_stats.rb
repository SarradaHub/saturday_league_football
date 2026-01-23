# frozen_string_literal: true

FactoryBot.define do
  factory :player_stat do
    goals { Faker::Number.between(from: 0, to: 2) }
    own_goals { Faker::Number.between(from: 0, to: 2) }
    # Assistência só existe se existir gol; gol contra não tem assistência.
    assists { |stat| stat.own_goals.to_i.positive? ? 0 : Faker::Number.between(from: 0, to: [stat.goals, 2].min) }
    was_goalkeeper { [true, false].sample }

    trait :with_player do
      player { FactoryBot.create(:player) }
    end

    trait :with_team do
      team { FactoryBot.create(:team) }
    end

    trait :with_match do
      match { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
    end
  end
end
