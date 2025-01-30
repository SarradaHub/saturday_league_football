# frozen_string_literal: true

json.id championship.id
json.name championship.name
json.description championship.description
json.total_players championship.total_players
json.round_total championship.round_total
json.created_at championship.created_at
json.updated_at championship.updated_at

json.rounds do
  json.array! championship.rounds.order(round_date: :asc), partial: 'api/v1/rounds/round_list', as: :round
end

json.players do
  json.array! championship.players.distinct, partial: 'api/v1/players/player_list', as: :player
end
