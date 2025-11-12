# frozen_string_literal: true

json.id team.id
json.name team.name
json.round_id team.round_id
team_players = team.ordered_players
json.player_count team_players.size
json.created_at team.created_at
json.updated_at team.updated_at

json.players do
  json.array! team_players, partial: 'api/v1/players/player_list', as: :player
end
