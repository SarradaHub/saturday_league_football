# frozen_string_literal: true

class PlayerRound < ApplicationRecord
  belongs_to :player
  belongs_to :round, counter_cache: :players_count

  after_commit :auto_balance_round_teams, on: %i[create destroy]
  after_commit :update_championship_players_count, on: %i[create destroy]

  private

  def auto_balance_round_teams
    return unless round.present?

    RoundTeamGenerator.call(round)
  end

  def update_championship_players_count
    return unless round&.championship.present?

    Championships::UpdatePlayersCount.call(championship: round.championship)
  end
end
