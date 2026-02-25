# frozen_string_literal: true

module Substitutions
  class ReplacePlayer < ApplicationService
    class PlayerNotInRoundError < StandardError; end
    class NoAvailablePlayerError < StandardError; end

    def initialize(*args, round: nil, player_id: nil, match_id: nil, **_kwargs)
      if round.nil? && args.first.is_a?(Hash)
        options = args.first
        round = options[:round]
        player_id = options[:player_id]
        match_id = options[:match_id]
      end

      @round = round
      @player_id = player_id
      @match_id = match_id
    end

    def call
      validate_player_in_round!
      replacement_player = find_next_available_player
      raise NoAvailablePlayerError, 'No available player to replace' if replacement_player.blank?

      ActiveRecord::Base.transaction do
        player_round = round.player_rounds.find_by(player_id: player_id)
        player_round&.destroy

        pr = round.player_rounds.unscoped.find_by(player_id: replacement_player.id)
        if pr
          pr.update!(is_deleted: false) if pr.is_deleted?
        else
          round.player_rounds.create!(player: replacement_player)
        end
      end

      {
        removed_player_id: player_id,
        replacement_player_id: replacement_player.id,
        replacement_player_name: replacement_player.display_name
      }
    end

    private

    attr_reader :round, :player_id, :match_id

    def validate_player_in_round!
      unless round.players.exists?(id: player_id)
        raise PlayerNotInRoundError, "Player #{player_id} is not in round #{round.id}"
      end
    end

    def find_next_available_player
      teams_ordered = round.teams.not_blocked.order(:created_at).to_a
      active_team_ids = active_match_team_ids

      teams_ordered.each do |team|
        next if active_team_ids.include?(team.id) || team.players.empty?

        scope = team.players.where.not(id: player_id)
        candidate = scope.joins(:player_rounds)
                         .where(player_rounds: { round_id: round.id, blocked: false })
                         .order('player_rounds.created_at ASC')
                         .first
        return candidate if candidate.present?

        candidate = scope.first
        return candidate if candidate.present?
      end

      nil
    end

    def active_match_team_ids
      return [] if match_id.blank?

      match = round.matches.find_by(id: match_id)
      return [] if match.blank?

      [match.team_1_id, match.team_2_id].compact
    end
  end
end
