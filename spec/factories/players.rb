# frozen_string_literal: true

FactoryBot.define do
  factory :player do
    name { "#{Faker::Sports::Football.player} #{Faker::Sports::Football.position}" }
  end
end
