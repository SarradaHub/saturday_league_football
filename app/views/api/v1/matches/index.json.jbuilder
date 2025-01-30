# frozen_string_literal: true

json.array! @matches, partial: 'api/v1/matches/match_list', as: :match
