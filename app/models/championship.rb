# frozen_string_literal: true

class Championship < ApplicationRecord
  belongs_to :user

  has_many :rounds, counter_cache: true
  has_many :player_rounds, through: :rounds
  has_many :players, through: :player_rounds

  validates_presence_of :name
  validates :user_id, presence: true
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

  after_commit :update_players_count, on: %i[create update]

  private

  def max_players_not_less_than_min
    return if min_players_per_team.nil? || max_players_per_team.nil?

    return unless max_players_per_team < min_players_per_team

    errors.add(:max_players_per_team, :greater_than_or_equal_to, count: min_players_per_team)
  end

  def update_players_count
    Championships::UpdatePlayersCount.call(championship: self)
  end
end
