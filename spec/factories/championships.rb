# frozen_string_literal: true

FactoryBot.define do
  factory :championship do
    name { Faker::Sports::Football.competition }
    description { Faker::TvShows::TheOffice.quote }
    min_players_per_team { 0 }
    max_players_per_team { 12 }
    user
  end
end
