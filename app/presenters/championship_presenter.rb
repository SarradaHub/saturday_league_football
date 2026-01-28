# frozen_string_literal: true

class ChampionshipPresenter < ApplicationPresenter
  delegate :id, :name, :description, :min_players_per_team, :max_players_per_team, :created_at, :updated_at, to: :resource

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      description: description,
      min_players_per_team: min_players_per_team,
      max_players_per_team: max_players_per_team,
      total_players: total_players,
      round_total: round_total,
      created_at: created_at,
      updated_at: updated_at
    }
    
    # Only serialize rounds and players if explicitly requested
    result[:rounds] = serialized_rounds if options[:include_rounds] || resource.association(:rounds).loaded?
    
    # For players, check if explicitly requested, directly loaded, or available through loaded rounds
    players_available = options[:include_players] || 
                        resource.association(:players).loaded? ||
                        (resource.association(:rounds).loaded? && resource.rounds.any? && 
                         resource.rounds.first.association(:player_rounds).loaded?)
    result[:players] = serialized_players if players_available
    
    result
  end

  def round_total
    resource.rounds_count || 0
  end

  def total_players
    resource.players_count || 0
  end

  def rounds
    resource.rounds.order(round_date: :asc)
  end

  def players
    # If rounds are loaded with player_rounds and players, collect players from there
    # to avoid N+1 queries when players association is not directly loaded
    if resource.association(:rounds).loaded? && resource.rounds.any?
      loaded_players = resource.rounds.flat_map do |round|
        round.association(:player_rounds).loaded? ? round.player_rounds.map(&:player).compact : []
      end.uniq
      return loaded_players if loaded_players.any?
    end
    
    # Fallback to direct association access
    resource.players.distinct
  end

  private

  def serialized_rounds
    rounds.map { |round| RoundSerializer.new(round).as_json }
  end

  def serialized_players
    players.map { |player| PlayerPresenter.new(player).as_json }
  end
end
