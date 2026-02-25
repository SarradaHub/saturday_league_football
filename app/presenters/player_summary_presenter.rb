# frozen_string_literal: true

class PlayerSummaryPresenter < ApplicationPresenter
  delegate :id, :display_name, :created_at, to: :resource

  def as_json(*)
    {
      id: id,
      display_name: display_name,
      total_goals: total_goals,
      total_assists: total_assists,
      total_own_goals: total_own_goals,
      total_matches: total_matches,
      created_at: created_at
    }
  end

  private

  def total_goals
    resource.player_stats.sum(:goals)
  end

  def total_assists
    resource.player_stats.sum(:assists)
  end

  def total_own_goals
    resource.player_stats.sum(:own_goals)
  end

  def total_matches
    team_ids = resource.teams.pluck(:id).uniq
    return 0 if team_ids.empty?

    Match.where(team_1_id: team_ids).or(Match.where(team_2_id: team_ids)).distinct.count
  end
end
