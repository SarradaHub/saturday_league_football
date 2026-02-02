# frozen_string_literal: true

module Rounds
  class NextMatchGenerator < ApplicationService
    class NotEnoughTeamsError < StandardError; end
    class WinnerSelectionRequiredError < StandardError; end
    class InvalidWinnerError < StandardError; end

    def initialize(round:, winner_team_id: nil, create_match: false)
      @round = round
      @winner_team_id = winner_team_id
      @create_match = create_match
    end

    def call
      state = compute_state

      if state[:needs_winner_selection]
        return winner_selection_payload(state) unless create_match
        return create_match_from_selection(state)
      end

      return suggestion_payload(state) unless create_match

      create_match_from_state(state)
    end

    private

    attr_reader :round, :winner_team_id, :create_match

    def compute_state
      teams_ordered = round.teams.not_blocked.order(:created_at).to_a
      raise NotEnoughTeamsError, 'Not enough teams to create a match' if teams_ordered.size < 2

      completed_matches = round.matches.includes(:team_1, :team_2, :winning_team)
                               .select { |match| match.draw.in?([true, false]) || match.winning_team_id.present? }
                               .sort_by(&:created_at)

      queue = teams_ordered.dup
      standing = queue.shift
      incoming = queue.shift

      completed_matches.each_with_index do |match, index|
        standing, incoming, queue = align_match_teams(
          standing:,
          incoming:,
          queue:,
          match:,
          teams_ordered:
        )

        result = match_result(match)

        if result == :draw
          full_next = queue.select { |team| team.present? && full_team?(team) && !team.is_blocked? }
          if index == completed_matches.size - 1 && full_next.size == 1
            return {
              needs_winner_selection: true,
              candidates: [standing, incoming],
              next_opponent: full_next.first,
              queue:,
              last_match: match
            }
          end

          if full_next.size >= 2
            # Add the teams from the draw to the queue
            queue = queue + [standing, incoming].compact.reject { |team| team.is_blocked? }
            # Use the first two full teams from the queue as standing and incoming
            standing = full_next[0]
            incoming = full_next[1]
            # Remove these teams from the queue
            queue = queue.reject { |team| team.id == standing.id || team.id == incoming.id }
          else
            queue = queue + [standing].compact.reject { |team| team.is_blocked? }
            standing = incoming
            incoming = queue.shift
          end
        else
          winner = resolve_winner(match, standing, incoming)
          loser = winner.id == standing.id ? incoming : standing
          queue = queue + [loser] if loser.present? && !loser.is_blocked?
          standing = winner
          incoming = queue.shift
        end
      end

      raise NotEnoughTeamsError, 'Not enough teams to create a match' if standing.blank? || incoming.blank?

      # Final filter to ensure no blocked teams in queue
      queue = queue.compact.reject { |team| team.is_blocked? }

      {
        standing: standing,
        incoming: incoming,
        queue: queue,
        last_match: completed_matches.last
      }
    end

    def match_result(match)
      return :draw if match.draw == true
      return :draw if match.draw.nil? && match.winning_team_id.blank?

      match.winning_team_id.present? ? :win : :draw
    end

    def resolve_winner(match, standing, incoming)
      return match.winning_team if match.winning_team.present?

      if match.winning_team_id == standing.id
        standing
      elsif match.winning_team_id == incoming.id
        incoming
      else
        raise InvalidWinnerError, 'Winning team is not part of the match'
      end
    end

    def align_match_teams(standing:, incoming:, queue:, match:, teams_ordered:)
      match_team_ids = [match.team_1_id, match.team_2_id].compact
      return [standing, incoming, queue] if standing.present? && incoming.present? &&
                                           match_team_ids.sort == [standing.id, incoming.id].sort

      if standing.present? && match_team_ids.include?(standing.id)
        incoming = match.team_1_id == standing.id ? match.team_2 : match.team_1
      else
        standing = match.team_1
        incoming = match.team_2
      end

      # Ensure standing and incoming are not blocked
      standing = nil if standing.present? && standing.is_blocked?
      incoming = nil if incoming.present? && incoming.is_blocked?

      queue = rebuild_queue(teams_ordered, [standing, incoming].compact, queue)
      [standing, incoming, queue]
    end

    def rebuild_queue(teams_ordered, active_teams, current_queue)
      active_ids = active_teams.compact.map(&:id)
      base_queue = current_queue.presence || teams_ordered
      cleaned = base_queue.compact.reject { |team| team.nil? || active_ids.include?(team.id) || team.is_blocked? }

      # Ensure all teams are present in order (excluding blocked teams)
      existing_ids = cleaned.map(&:id)
      teams_ordered.compact.each do |team|
        next if team.nil? || active_ids.include?(team.id) || existing_ids.include?(team.id) || team.is_blocked?

        cleaned << team
      end

      cleaned
    end

    def full_team?(team)
      max = round.championship&.max_players_per_team.to_i
      return true unless max.positive?

      team_size = team.players_count || team.players.count
      team_size >= max
    end

    def suggestion_payload(state)
      {
        needs_winner_selection: false,
        suggested_match: {
          name: match_name(state[:standing], state[:incoming]),
          team_1: TeamSerializer.new(state[:standing]).as_json,
          team_2: TeamSerializer.new(state[:incoming]).as_json
        },
        queue: build_queue_for_payload(state)
      }
    end

    def winner_selection_payload(state)
      # Build queue starting with next_opponent (next team to play) followed by the rest of the queue
      queue_teams = state[:queue]&.compact&.reject { |team| team.nil? || team.is_blocked? } || []
      # Remove next_opponent from queue if it's already there to avoid duplication
      queue_teams = queue_teams.reject { |team| team.nil? || team.id == state[:next_opponent]&.id }
      full_queue = [state[:next_opponent]].compact + queue_teams
      full_queue = full_queue.reject { |team| team.nil? || team.is_blocked? }

      {
        needs_winner_selection: true,
        reason: 'first_match_draw_one_next_team',
        candidates: state[:candidates].map { |team| TeamSerializer.new(team).as_json },
        next_opponent: TeamSerializer.new(state[:next_opponent]).as_json,
        queue: full_queue.map { |team| TeamSerializer.new(team).as_json }
      }
    end

    def create_match_from_selection(state)
      raise WinnerSelectionRequiredError, 'Winner selection is required' if winner_team_id.blank?

      candidate_ids = state[:candidates].map(&:id)
      raise InvalidWinnerError, 'Winner is not a valid candidate' unless candidate_ids.include?(winner_team_id.to_i)

      winner = state[:candidates].find { |team| team.id == winner_team_id.to_i }
      loser = state[:candidates].find { |team| team.id != winner_team_id.to_i }
      incoming = state[:next_opponent]

      raise NotEnoughTeamsError, 'Not enough teams to create a match' if incoming.blank?

      queue = state[:queue] || []
      redistribute_losing_team_players!(loser, queue) if loser.present?

      match = Match.create!(
        round: round,
        name: match_name(winner, incoming),
        team_1: winner,
        team_2: incoming
      )

      # Recompute state after match creation to get updated queue
      new_state = compute_state
      updated_queue = build_queue_for_payload(new_state)

      { match: match, queue: updated_queue }
    end

    def create_match_from_state(state)
      standing = state[:standing]
      incoming = state[:incoming]
      last_match = state[:last_match]
      loser = loser_from_match(last_match, standing, incoming)

      queue = state[:queue] || []
      redistribute_losing_team_players!(loser, queue) if loser.present?

      match = Match.create!(
        round: round,
        name: match_name(standing, incoming),
        team_1: standing,
        team_2: incoming
      )

      # Recompute state after match creation to get updated queue
      new_state = compute_state
      updated_queue = build_queue_for_payload(new_state)

      { match: match, queue: updated_queue }
    end

    def loser_from_match(match, standing, incoming)
      return nil if match.blank?
      return nil if match.draw == true || match.winning_team_id.blank?

      winner = match.winning_team || resolve_winner(match, standing, incoming)
      winner.id == match.team_1_id ? match.team_2 : match.team_1
    end

    def fill_team_from_loser!(target_team, losing_team)
      max = round.championship&.max_players_per_team.to_i
      return if losing_team.blank? || target_team.blank? || !max.positive?

      current_size = target_team.players_count || target_team.players.count
      missing_slots = [max - current_size, 0].max
      return if missing_slots.zero?

      target_player_ids = target_team.players.pluck(:id)
      losing_team.player_teams.order(:created_at).includes(:player).each do |player_team|
        break if missing_slots.zero?

        player = player_team.player
        next if target_player_ids.include?(player.id)

        PlayerTeam.create!(player: player, team: target_team)
        target_player_ids << player.id
        missing_slots -= 1
      end
    end

    def redistribute_losing_team_players!(losing_team, queue)
      return nil if losing_team.blank?

      # Get players from losing team ordered by registration (player_rounds.created_at)
      # We need to get players in the order they were registered in this round
      losing_players = losing_team.player_teams
                                  .includes(:player)
                                  .order(:created_at)
                                  .map(&:player)
                                  .compact

      # Reorder by player_rounds.created_at to ensure registration order
      losing_players = losing_players.sort_by do |player|
        player_round = player.player_rounds.find_by(round_id: round.id)
        player_round&.created_at || Time.current
      end

      return nil if losing_players.empty?

      max_players_per_team = round.championship&.max_players_per_team.to_i
      return nil unless max_players_per_team.positive?

      # Check if there's an incomplete team in the queue
      incomplete_team = queue.find { |team| !full_team?(team) }

      remaining_players = losing_players.dup

      if incomplete_team.present?
        # Fill incomplete team with players from losing team
        current_size = incomplete_team.players_count || incomplete_team.players.count
        missing_slots = [max_players_per_team - current_size, 0].max

        if missing_slots.positive?
          target_player_ids = incomplete_team.players.pluck(:id)
          players_to_move = remaining_players.select { |player| !target_player_ids.include?(player.id) }.first(missing_slots)

          players_to_move.each do |player|
            PlayerTeam.create!(player: player, team: incomplete_team)
            remaining_players.delete(player)
          end
        end
      end

      # Create new team with remaining players (if any)
      new_team = nil
      if remaining_players.any?
        new_team = create_new_team_with_players(remaining_players)
      end

      # Block losing team
      losing_team.update!(is_blocked: true)

      new_team
    end

    def create_new_team_with_players(players)
      existing_names = round.teams.pluck(:name)
      team_name = unique_team_name(existing_names.length + 1, existing_names)

      new_team = round.teams.create!(name: team_name)

      players.each do |player|
        PlayerTeam.create!(player: player, team: new_team)
      end

      new_team
    end

    def unique_team_name(sequence, existing_names)
      candidate = "Time #{sequence}"
      while existing_names.include?(candidate)
        sequence += 1
        candidate = "Time #{sequence}"
      end
      candidate
    end

    def build_queue_for_payload(state)
      # Build queue starting with incoming (next team to play) followed by the rest of the queue
      queue_teams = state[:queue]&.compact&.reject { |team| team.nil? || team.is_blocked? } || []
      # Remove incoming from queue if it's already there to avoid duplication
      queue_teams = queue_teams.reject { |team| team.nil? || team.id == state[:incoming]&.id }
      full_queue = [state[:incoming]].compact + queue_teams
      full_queue = full_queue.reject { |team| team.nil? || team.is_blocked? }
      full_queue.map { |team| TeamSerializer.new(team).as_json }
    end

    def match_name(team_1, team_2)
      "#{team_1.name} vs #{team_2.name}"
    end
  end
end
