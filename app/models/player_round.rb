# frozen_string_literal: true

class PlayerRound < ApplicationRecord
  include SoftDeletable

  belongs_to :player
  belongs_to :round, counter_cache: :players_count

  after_commit :auto_balance_round_teams, on: %i[create destroy]
  after_commit :update_championship_players_count, on: %i[create destroy]

  private

  def auto_balance_round_teams
    return if destroyed_by_association
    return unless round.present?
    return if round.destroyed? || round.marked_for_destruction?

    RoundTeamGenerator.call(round)
  end

  def update_championship_players_count
    return if destroyed_by_association
    return unless round.present?
    return if round.destroyed? || round.marked_for_destruction?
    
    championship = round.championship
    return unless championship.present?
    return if championship.destroyed? || championship.marked_for_destruction?

    Championships::UpdatePlayersCount.call(championship: championship)
  end
end
