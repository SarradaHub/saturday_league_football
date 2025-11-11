# frozen_string_literal: true

class RoundSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: resource.id,
      name: resource.name,
      round_date: resource.round_date,
      championship_id: resource.championship_id,
      created_at: resource.created_at,
      updated_at: resource.updated_at
    }
  end
end
