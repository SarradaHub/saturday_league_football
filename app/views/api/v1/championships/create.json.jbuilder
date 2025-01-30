# frozen_string_literal: true

if @championship.persisted?
  json.status :created
  json.data do
    json.partial! 'championships/championship', resource: @championship
  end
else
  json.status :unprocessable_entity
  json.errors @championship.errors.full_messages
end
