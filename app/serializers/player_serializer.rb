# frozen_string_literal: true

class PlayerSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: resource.id,
      display_name: resource.display_name,
      first_name: resource.first_name,
      last_name: resource.last_name,
      nickname: resource.nickname
    }
  end
end
