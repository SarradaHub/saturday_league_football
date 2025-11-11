# frozen_string_literal: true

class TeamSerializer < ApplicationSerializer
  def as_json(*)
    return if resource.blank?

    {
      id: resource.id,
      name: resource.name,
      round_id: resource.round_id
    }
  end
end
