# frozen_string_literal: true

FactoryBot.define do
  factory :match do
    name { "#{Faker::Number.unique.number(digits: 3)}ª Partida" }
    draw { [true, false].sample }

    trait :with_round do
      round { FactoryBot.create(:round, :with_championship) }
    end

    trait :with_team_1 do
      team_1 { FactoryBot.create(:team) }
    end

    trait :with_team_2 do
      team_2 { FactoryBot.create(:team) }
    end

    trait :with_winning_team do
      winning_team_id { [team_1, team_2].sample }
    end
  end
end
