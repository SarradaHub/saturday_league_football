# frozen_string_literal: true

json.id team.id
json.name team.name
json.round_id team.round.id
json.player_count team.players.size
json.created_at team.created_at
json.updated_at team.updated_at

json.matches team.matches

json.players do
  json.array! team.players.distinct, partial: 'api/v1/players/player_list', as: :player
end
