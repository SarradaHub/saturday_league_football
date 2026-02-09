# frozen_string_literal: true

class PlayerStat < ApplicationRecord
  include SoftDeletable

  belongs_to :player, counter_cache: true
  belongs_to :team
  belongs_to :match

  validates_presence_of :goals
  validates_presence_of :assists
  validates_presence_of :own_goals
  validates :was_goalkeeper, inclusion: [true, false]
  validate :assists_require_goals
  validate :no_assists_on_own_goals
  validate :goalkeeper_not_line_player

  # Regra "goleiro de time externo": o goleiro pode ser qualquer jogador da rodada que não seja
  # jogador de linha na mesma partida (ex.: goleiro do Time 1 pode ser jogador do Time 3 ou Time 5).
  # A validação goalkeeper_not_line_player garante que o mesmo jogador não seja goleiro e jogador
  # de linha na mesma partida; não exige que o goleiro pertença a um time da partida.

  private

  def assists_require_goals
    return if assists.to_i.zero?

    team_goals = team_goals_total
    team_assists = team_assists_total
    return if team_goals >= team_assists

    errors.add(:assists, :assists_require_goals)
  end

  def no_assists_on_own_goals
    return unless own_goals.to_i.positive? && assists.to_i.positive?

    errors.add(:assists, :no_assists_on_own_goals)
  end

  def team_goals_total
    scope = PlayerStat.where(match_id: match_id, team_id: team_id)
    scope = scope.where.not(id: id) if persisted?
    scope.sum(:goals) + goals.to_i
  end

  def team_assists_total
    scope = PlayerStat.where(match_id: match_id, team_id: team_id)
    scope = scope.where.not(id: id) if persisted?
    scope.sum(:assists) + assists.to_i
  end

  def goalkeeper_not_line_player
    return unless was_goalkeeper == true

    line_player_stats = PlayerStat.where(match_id: match_id, player_id: player_id, was_goalkeeper: false)
    line_player_stats = line_player_stats.where.not(id: id) if persisted?

    if line_player_stats.exists?
      errors.add(:was_goalkeeper, :goalkeeper_not_line_player)
    end
  end
end
