# frozen_string_literal: true

class Team < ApplicationRecord
  has_many :player_teams, dependent: :destroy
  has_many :players, through: :player_teams
  belongs_to :round, optional: true

  accepts_nested_attributes_for :player_teams, allow_destroy: true

  validates_presence_of :name

  def matches
    Match.where('team_1_id = ? OR team_2_id = ?', id, id)
  end
end
