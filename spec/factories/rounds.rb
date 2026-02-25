# frozen_string_literal: true

FactoryBot.define do
  factory :round do
    championship { FactoryBot.create(:championship) }
    round_date { Faker::Date.on_day_of_week_between(day: :saturday, from: Time.now.beginning_of_year, to: Time.now.end_of_year) }
    name { round_date.strftime('%d/%m/%Y') }

    trait :with_championship do
      # kept for backwards compatibility; base factory already sets championship
    end
  end
end
