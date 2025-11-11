# frozen_string_literal: true

class Match < ApplicationRecord
  belongs_to :round
  belongs_to :team_1, class_name: 'Team', foreign_key: 'team_1_id'
  belongs_to :team_2, class_name: 'Team', foreign_key: 'team_2_id'
  belongs_to :winning_team, class_name: 'Team', foreign_key: 'winning_team_id', optional: true

  validates :name, presence: true
end
