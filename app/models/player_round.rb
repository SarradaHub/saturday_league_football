# frozen_string_literal: true

class PlayerRound < ApplicationRecord
  belongs_to :player
  belongs_to :round

  after_commit :auto_balance_round_teams, on: %i[create destroy]

  private

  def auto_balance_round_teams
    return unless round.present?

    RoundTeamGenerator.call(round)
  end
end
