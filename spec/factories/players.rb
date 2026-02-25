# frozen_string_literal: true

FactoryBot.define do
  factory :player do
    first_name { Faker::Sports::Football.player.strip }
    last_name { Faker::Sports::Football.position.strip }
    nickname { "#{first_name.split(' ').last} #{last_name}" }
  end
end
