# frozen_string_literal: true

class Player < ApplicationRecord
  include SoftDeletable

  has_many :player_stats, dependent: :destroy, counter_cache: true
  has_many :player_teams, dependent: :destroy
  accepts_nested_attributes_for :player_teams, allow_destroy: true
  has_many :teams, through: :player_teams
  has_many :player_rounds, dependent: :destroy
  accepts_nested_attributes_for :player_rounds, allow_destroy: true
  has_many :rounds, through: :player_rounds
  has_many :championships, through: :rounds

  validates_presence_of :name

  before_destroy :cleanup_round_and_team_links

  scope :in_championship, lambda { |championship_id|
    joins(player_rounds: :round)
      .where(rounds: { championship_id: championship_id })
      .distinct
  }

  private

  def cleanup_round_and_team_links
    # Ensure dependent rows are removed before the player to satisfy FK constraints.
    player_rounds.destroy_all
    player_teams.destroy_all
  end
end
