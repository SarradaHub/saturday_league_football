# frozen_string_literal: true

class PlayerPresenter < ApplicationPresenter
  delegate :id, :name, :created_at, :updated_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      rounds: serialized_rounds,
      total_goals: total_goals,
      total_assists: total_assists,
      total_own_goals: total_own_goals,
      total_matches: total_matches,
      player_stats: serialized_stats,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def rounds
    resource.rounds
  end

  def player_stats
    resource.player_stats
  end

  def total_goals
    @total_goals ||= player_stats.sum(:goals)
  end

  def total_assists
    @total_assists ||= player_stats.sum(:assists)
  end

  def total_own_goals
    @total_own_goals ||= player_stats.sum(:own_goals)
  end

  def total_matches
    team_ids = resource.teams.pluck(:id)
    return 0 if team_ids.empty?

    Match.where(team_1_id: team_ids).or(Match.where(team_2_id: team_ids)).distinct.count
  end

  private

  def serialized_rounds
    rounds.map { |round| RoundSerializer.new(round).as_json }
  end

  def serialized_stats
    player_stats.map { |stat| PlayerStatSerializer.new(stat).as_json }
  end
end
