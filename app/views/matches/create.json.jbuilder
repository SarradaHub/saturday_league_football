# frozen_string_literal: true

if @match.persisted?
  json.status :created
  json.data do
    json.partial! 'matches/match', resource: @match
  end
else
  json.status :unprocessable_entity
  json.errors @match.errors.full_messages
end
