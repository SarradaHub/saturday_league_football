# frozen_string_literal: true

json.id round.id
json.name round.name
json.round_date round.round_date
json.championship_id round.championship.id
json.created_at round.created_at
json.updated_at round.updated_at

json.matches do
  json.array! round.matches, partial: 'matches/match_list', as: :match
end

json.players do
  json.array! round.players.distinct, partial: 'players/player_list', as: :player
end
