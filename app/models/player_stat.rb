# frozen_string_literal: true

class PlayerStat < ApplicationRecord
  belongs_to :player, counter_cache: true, dependent: :destroy
  belongs_to :team, dependent: :destroy
  belongs_to :match, dependent: :destroy

  validates_presence_of :goals
  validates_presence_of :assists
  validates_presence_of :own_goals
  validates :was_goalkeeper, inclusion: [true, false]
  validate :assists_require_goals
  validate :no_assists_on_own_goals

  private

  def assists_require_goals
    return if assists.to_i.zero?

    team_goals = team_goals_total
    team_assists = team_assists_total
    return if team_goals >= team_assists

    errors.add(:assists, :assists_require_goals)
  end

  def no_assists_on_own_goals
    return unless own_goals.to_i.positive? && assists.to_i.positive?

    errors.add(:assists, :no_assists_on_own_goals)
  end

  def team_goals_total
    scope = PlayerStat.where(match_id: match_id, team_id: team_id)
    scope = scope.where.not(id: id) if persisted?
    scope.sum(:goals) + goals.to_i
  end

  def team_assists_total
    scope = PlayerStat.where(match_id: match_id, team_id: team_id)
    scope = scope.where.not(id: id) if persisted?
    scope.sum(:assists) + assists.to_i
  end
end
