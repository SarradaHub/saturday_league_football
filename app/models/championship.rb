# frozen_string_literal: true

class Championship < ApplicationRecord
  has_many :rounds
  has_many :player_rounds, through: :rounds
  has_many :players, through: :player_rounds

  validates_presence_of :name
  validates :min_players_per_team,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_players_per_team,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validate :max_players_not_less_than_min

  scope :with_players, lambda {
    includes(rounds: { player_rounds: :player })
      .references(:players)
      .merge(Player.distinct)
  }

  def round_total
    rounds.count
  end

  def total_players
    players.distinct.count
  end

  private

  def max_players_not_less_than_min
    return if min_players_per_team.nil? || max_players_per_team.nil?

    return unless max_players_per_team < min_players_per_team

    errors.add(:max_players_per_team, :greater_than_or_equal_to, count: min_players_per_team)
  end
end
