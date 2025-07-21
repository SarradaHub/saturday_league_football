# frozen_string_literal: true

json.id team.id
json.name team.name
json.team_id team.round.id
json.created_at team.created_at
json.updated_at team.updated_at

json.players do
  json.array! team.players.distinct, partial: 'api/v1/players/player_list', as: :player
end
