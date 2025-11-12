# frozen_string_literal: true

FactoryBot.define do
  factory :championship do
    name { Faker::Sports::Football.competition }
    description { Faker::TvShows::TheOffice.quote }
    min_players_per_team { 5 }
    max_players_per_team { 12 }
  end
end
