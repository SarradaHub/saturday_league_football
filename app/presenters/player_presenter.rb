# frozen_string_literal: true

class PlayerPresenter < ApplicationPresenter
  delegate :id, :name, :created_at, :updated_at, to: :resource

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      total_goals: total_goals,
      total_assists: total_assists,
      total_own_goals: total_own_goals,
      total_matches: total_matches,
      created_at: created_at,
      updated_at: updated_at
    }

    # Only serialize rounds if not explicitly skipped (prevents circular reference in round context)
    result[:rounds] = serialized_rounds unless options[:skip_rounds]

    # Only serialize player_stats if not explicitly skipped (reduces payload in nested contexts)
    result[:player_stats] = serialized_stats unless options[:skip_player_stats]

    result
  end

  def rounds
    @rounds ||= begin
      # Priority 1: Check if player_rounds are loaded (most common case with eager loading)
      if resource.association(:player_rounds).loaded?
        # Extract rounds from loaded player_rounds
        # This works when eager loading includes({ player_rounds: :round })
        resource.player_rounds.map(&:round).compact.uniq
      # Priority 2: Check if rounds association is directly loaded
      elsif resource.association(:rounds).loaded?
        resource.rounds
      # Priority 3: Fallback to loading rounds
      else
        resource.rounds.load
      end
    end
  end

  def player_stats
    @player_stats ||= resource.association(:player_stats).loaded? ? resource.player_stats : resource.player_stats.load
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
    # Use loaded associations if available to avoid N+1 queries
    team_ids = if resource.association(:player_teams).loaded?
                 # Teams are loaded through player_teams, extract team_ids from loaded association
                 resource.player_teams.map(&:team_id).compact.uniq
               elsif resource.association(:teams).loaded?
                 # Teams association is directly loaded
                 resource.teams.map(&:id).compact.uniq
               else
                 # Fallback to query if not loaded
                 resource.teams.pluck(:id)
               end

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
