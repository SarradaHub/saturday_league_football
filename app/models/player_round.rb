# frozen_string_literal: true

class PlayerRound < ApplicationRecord
  include SoftDeletable

  belongs_to :player
  belongs_to :round, counter_cache: :players_count

  attribute :goalkeeper_only, :boolean, default: false

  after_commit :auto_balance_round_teams, on: :create
  after_commit :update_championship_players_count, on: :create
  after_destroy :auto_balance_round_teams
  after_destroy :update_championship_players_count

  private

  def auto_balance_round_teams
    return if destroyed_by_association
    return unless round.present?
    return if round.destroyed? || round.marked_for_destruction?
    return if respond_to?(:goalkeeper_only) && goalkeeper_only?

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
