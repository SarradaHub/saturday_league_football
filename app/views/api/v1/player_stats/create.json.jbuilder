# frozen_string_literal: true

if @player_stat.persisted?
  json.status :created
  json.data do
    json.partial! 'api/v1/player_stats/stat', resource: @player_stat
  end
else
  json.status :unprocessable_entity
  json.errors @player_stat.errors.full_messages
end
