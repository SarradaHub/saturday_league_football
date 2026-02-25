# frozen_string_literal: true

class Team < ApplicationRecord
  include SoftDeletable

  has_many :player_teams, -> { order(created_at: :asc) }, dependent: :destroy, counter_cache: :players_count
  has_many :players, through: :player_teams
  has_many :player_stats, dependent: :destroy
  has_many :matches_as_team_1, class_name: 'Match', foreign_key: 'team_1_id', dependent: :destroy
  has_many :matches_as_team_2, class_name: 'Match', foreign_key: 'team_2_id', dependent: :destroy
  has_many :matches_as_winner, class_name: 'Match', foreign_key: 'winning_team_id', dependent: :destroy
  belongs_to :round, optional: true

  accepts_nested_attributes_for :player_teams, allow_destroy: true

  validates_presence_of :name

  scope :not_blocked, -> { where(is_blocked: false) }

  # Jogadores na ordem de inscrição no time (player_teams.created_at).
  def ordered_players
    player_teams.includes(:player).order(created_at: :asc).map(&:player).compact
  end
end
