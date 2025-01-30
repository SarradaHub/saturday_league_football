# frozen_string_literal: true

json.array! @matches, partial: 'matches/match_list', as: :match
