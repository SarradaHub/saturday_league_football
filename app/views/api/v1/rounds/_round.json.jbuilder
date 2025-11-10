# frozen_string_literal: true

json.id round.id
json.name round.name
json.round_date round.round_date
json.championship_id round.championship.id
json.created_at round.created_at
json.updated_at round.updated_at

json.matches do
  json.array! round.matches, partial: 'api/v1/matches/match_list', as: :match
end

round_players = defined?(@players) ? @players : round.players.distinct

json.players do
  json.array! round_players, partial: 'api/v1/players/player_list', as: :player
end

json.teams do
  json.array! round.teams.includes(player_teams: :player).order(:created_at),
              partial: 'api/v1/teams/team_summary', as: :team
end
