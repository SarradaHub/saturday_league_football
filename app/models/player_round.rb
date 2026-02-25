# frozen_string_literal: true

class PlayerRound < ApplicationRecord
  include SoftDeletable

  belongs_to :player
  belongs_to :round, counter_cache: :players_count

  attribute :goalkeeper_only, :boolean, default: false

  after_commit :auto_balance_round_teams_on_create, on: :create
  after_commit :update_championship_players_count, on: :create
  after_destroy :auto_balance_round_teams_on_destroy
  after_destroy :update_championship_players_count

  private

  def auto_balance_round_teams_on_create
    return if destroyed_by_association
    return unless round.present?
    return if round.destroyed? || round.marked_for_destruction?
    return if respond_to?(:goalkeeper_only) && goalkeeper_only?

    if round_has_finalized_matches?
      Rounds::AddPlayerToLastActiveTeam.call(round: round, player: player)
    else
      Rounds::RoundTeamGenerator.call(round)
    end
  end

  def auto_balance_round_teams_on_destroy
    return if destroyed_by_association
    return unless round.present?
    return if round.destroyed? || round.marked_for_destruction?

    Rounds::RoundTeamGenerator.call(round)
  end

  def round_has_finalized_matches?
    round.matches.where('draw IN (true, false) OR winning_team_id IS NOT NULL').exists?
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
