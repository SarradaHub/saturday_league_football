# frozen_string_literal: true

class PlayerSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: resource.id,
      name: resource.name
    }
  end
end
