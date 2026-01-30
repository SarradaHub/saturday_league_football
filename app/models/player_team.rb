# frozen_string_literal: true

class PlayerTeam < ApplicationRecord
  include SoftDeletable

  belongs_to :player
  belongs_to :team, counter_cache: :players_count

  validate :team_has_capacity, on: :create
  before_destroy :ensure_team_remains_above_minimum

  private

  def team_has_capacity
    return unless team.present?

    championship = team.round&.championship
    return unless championship.present?

    max = championship.max_players_per_team
    return unless max.positive?

    current_size = team.players_count || 0
    return if current_size < max

    errors.add(:team, "has already reached the maximum of #{max} players")
  end

  def ensure_team_remains_above_minimum
    return if destroyed_by_association
    return unless team.present?

    championship = team.round&.championship
    return unless championship.present?

    min = championship.min_players_per_team
    return unless min.positive?

    current_size = team.players_count || 0
    return unless current_size <= min

    errors.add(:team, :greater_than_or_equal_to, count: min)
    throw(:abort)
  end
end
