# frozen_string_literal: true

FactoryBot.define do
  factory :championship do
    name { Faker::Sports::Football.competition }
    description { Faker::TvShows::TheOffice.quote }
  end
end
