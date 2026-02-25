# frozen_string_literal: true

class RoundSummaryPresenter < ApplicationPresenter
  delegate :id, :name, :round_date, :championship_id, :created_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      round_date: round_date,
      championship_id: championship_id,
      matches_count: matches_count,
      players_count: players_count,
      created_at: created_at
    }
  end

  private

  def matches_count
    resource.matches_count || 0
  end

  def players_count
    resource.players_count || 0
  end
end
