# frozen_string_literal: true

if @team.persisted?
  json.status :created
  json.data do
    json.partial! 'api/v1/teams/team', resource: @team
  end
else
  json.status :unprocessable_entity
  json.errors @team.errors.full_messages
end
