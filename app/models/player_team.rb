# frozen_string_literal: true

class PlayerTeam < ApplicationRecord
  belongs_to :player
  belongs_to :team

  validate :team_has_capacity, on: :create
  before_destroy :ensure_team_remains_above_minimum

  private

  def team_has_capacity
    return unless team.present?

    championship = team.round&.championship
    return unless championship.present?

    max = championship.max_players_per_team
    return unless max.positive?

    current_size = team.player_teams.count
    return if current_size < max

    errors.add(:team, "has already reached the maximum of #{max} players")
  end

  def ensure_team_remains_above_minimum
    return unless team.present?

    championship = team.round&.championship
    return unless championship.present?

    min = championship.min_players_per_team
    return unless min.positive?

    current_size = team.player_teams.count
    return unless current_size <= min

    errors.add(:team, :greater_than_or_equal_to, count: min)
    throw(:abort)
  end
end
