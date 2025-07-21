# frozen_string_literal: true

class Player < ApplicationRecord
  has_many :player_stats, dependent: :destroy
  has_many :player_teams, dependent: :destroy
  accepts_nested_attributes_for :player_teams, allow_destroy: true
  has_many :teams, through: :player_teams
  has_many :player_rounds
  accepts_nested_attributes_for :player_rounds, allow_destroy: true
  has_many :rounds, through: :player_rounds
  has_many :championships, through: :rounds

  validates_presence_of :name

  scope :in_championship, lambda { |championship_id|
    joins(player_rounds: :round)
      .where(rounds: { championship_id: championship_id })
      .distinct
  }

  def total_goals
    player_stats.sum(:goals)
  end

  def total_assists
    player_stats.sum(:assists)
  end

  def total_own_goals
    player_stats.sum(:own_goals)
  end

  def goals_in_match(match)
    player_stats.where(match: match).sum(:goals)
  end

  def assists_in_match(match)
    player_stats.where(match: match).sum(:assists)
  end

  def own_goals_in_match(match)
    player_stats.where(match: match).sum(:own_goals)
  end
end
