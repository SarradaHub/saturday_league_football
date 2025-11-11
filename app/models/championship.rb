# frozen_string_literal: true

class Championship < ApplicationRecord
  has_many :rounds
  has_many :player_rounds, through: :rounds
  has_many :players, through: :player_rounds

  validates_presence_of :name

  scope :with_players, lambda {
    includes(rounds: { player_rounds: :player })
      .references(:players)
      .merge(Player.distinct)
  }
end
