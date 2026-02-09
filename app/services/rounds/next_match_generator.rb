# frozen_string_literal: true

# Generates the next match for a round following the automatic match sequence.
# Does not use was_goalkeeper from previous matches: goalkeeper designation is per-match only.
# Player order for completing the waiting team and queue uses only registration order in the
# round (player_rounds.created_at), not was_goalkeeper.
module Rounds
  class NextMatchGenerator < ApplicationService
    # Same rule as RoundTeamGenerator: 1 slot reserved for (external) goalkeeper
    RESERVED_SLOTS_FOR_GOALKEEPER = 1

    class NotEnoughTeamsError < StandardError; end
    class WinnerSelectionRequiredError < StandardError; end
    class InvalidWinnerError < StandardError; end

    def self.redistribute_after_finalize(match)
      round = match.round
      instance = new(round: round, create_match: false)
      instance.send(:redistribute_for_finalized_match!)
    end

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
            queue = queue + [standing, incoming].compact.reject { |team| team.is_blocked? }
            standing = full_next[0]
            incoming = full_next[1]
            queue = queue.reject { |team| team.id == standing.id || team.id == incoming.id }
          else
            queue = queue + [standing].compact.reject { |team| team.is_blocked? }
            standing = incoming
            incoming = queue.shift
          end
        else
          winner = resolve_winner(match, standing, incoming)
          next if winner.blank?

          loser = match.team_1_id == winner.id ? match.team_2 : match.team_1
          queue = queue + [loser] if loser.present? && !loser.is_blocked?
          standing = winner
          incoming = queue.shift
        end
      end

      raise NotEnoughTeamsError, 'Not enough teams to create a match' if standing.blank? || incoming.blank?

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
      return nil if match.winning_team_id.blank?

      if standing.blank? || incoming.blank?
        return match.team_1 if match.winning_team_id == match.team_1_id
        return match.team_2 if match.winning_team_id == match.team_2_id
        raise InvalidWinnerError, 'Winning team is not part of the match'
      end

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

      standing = nil if standing.present? && standing.is_blocked?
      incoming = nil if incoming.present? && incoming.is_blocked?

      queue = rebuild_queue(teams_ordered, [standing, incoming].compact, queue)
      [standing, incoming, queue]
    end

    def rebuild_queue(teams_ordered, active_teams, current_queue)
      active_ids = active_teams.compact.map(&:id)
      base_queue = current_queue.presence || teams_ordered
      cleaned = base_queue.compact.reject { |team| team.nil? || active_ids.include?(team.id) || team.is_blocked? }

      existing_ids = cleaned.map(&:id)
      teams_ordered.compact.each do |team|
        next if team.nil? || active_ids.include?(team.id) || existing_ids.include?(team.id) || team.is_blocked?

        cleaned << team
      end

      cleaned
    end

    # Team is "full" when it has slots_per_team players (max - 1, reserving 1 for goalkeeper), same as RoundTeamGenerator
    def full_team?(team)
      slots = slots_per_team
      return true unless slots.positive?

      team_size = team.players_count || team.players.count
      team_size >= slots
    end

    def slots_per_team
      max = round.championship&.max_players_per_team.to_i
      [max - RESERVED_SLOTS_FOR_GOALKEEPER, 1].max
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
      queue_teams = state[:queue]&.compact&.reject { |team| team.nil? || team.is_blocked? } || []
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

      match = Match.create!(
        round: round,
        name: match_name(winner, incoming),
        team_1: winner,
        team_2: incoming
      )

      new_state = compute_state
      updated_queue = build_queue_for_payload(new_state)

      { match: match, queue: updated_queue }
    end

    def create_match_from_state(state)
      redistribute_for_finalized_match! if state[:last_match].present?

      standing = state[:standing]
      incoming = state[:incoming]

      match = Match.create!(
        round: round,
        name: match_name(standing, incoming),
        team_1: standing,
        team_2: incoming
      )

      new_state = compute_state
      updated_queue = build_queue_for_payload(new_state)

      { match: match, queue: updated_queue }
    end

    def redistribute_for_finalized_match!
      state = compute_state
      last_match = state[:last_match]
      return if last_match.blank?

      loser = loser_from_match(last_match, state[:standing], state[:incoming])
      queue = state[:queue] || []
      redistribute_losing_team_players!(loser, queue, incoming: state[:incoming]) if loser.present?
    end

    def loser_from_match(match, standing, incoming)
      return nil if match.blank?
      return nil if match.draw == true || match.winning_team_id.blank?

      winner = match.winning_team || resolve_winner(match, standing, incoming)
      winner.id == match.team_1_id ? match.team_2 : match.team_1
    end

    def fill_team_from_loser!(target_team, losing_team)
      slots = slots_per_team
      return if losing_team.blank? || target_team.blank? || !slots.positive?

      current_size = target_team.players_count || target_team.players.count
      missing_slots = [slots - current_size, 0].max
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

    # Redistributes losing team players: fill the incoming team (waiting to play) if incomplete,
    # then any other incomplete team in the queue, then create a new team with the rest.
    # Order is strictly by inscription in the round; does not consider was_goalkeeper.
    def redistribute_losing_team_players!(losing_team, queue, incoming: nil)
      return nil if losing_team.blank?

      losing_team.update!(is_blocked: true)

      losing_players = losing_team.player_teams
                                  .includes(:player)
                                  .order(:created_at)
                                  .map(&:player)
                                  .compact

      losing_players = losing_players.sort_by do |player|
        player_round = player.player_rounds.find_by(round_id: round.id)
        player_round&.created_at || Time.current
      end

      return nil if losing_players.empty?

      slots = slots_per_team
      return nil unless slots.positive?

      remaining_players = losing_players.dup

      fill_team_with_losing_players!(incoming, remaining_players, slots) if incoming.present?

      incomplete_team = queue.find { |team| team.id != losing_team.id && !full_team?(team) }
      fill_team_with_losing_players!(incomplete_team, remaining_players, slots) if incomplete_team.present?

      new_team = nil
      if remaining_players.any?
        new_team = create_new_team_with_players(remaining_players)
      end

      new_team
    end

    # Adds players from remaining_players to the target team (in order) until it has target_slots
    # (max - 1, reserving 1 for goalkeeper). Does not remove from losing team; keeps history.
    def fill_team_with_losing_players!(team, remaining_players, target_slots)
      return if team.blank? || remaining_players.empty?

      current_size = team.players_count || team.players.count
      missing_slots = [target_slots - current_size, 0].max
      return if missing_slots.zero?

      target_player_ids = team.players.pluck(:id)
      players_to_move = remaining_players.select { |player| !target_player_ids.include?(player.id) }.first(missing_slots)

      players_to_move.each do |player|
        PlayerTeam.create!(player: player, team: team)
        remaining_players.delete(player)
      end
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
      queue_teams = state[:queue]&.compact&.reject { |team| team.nil? || team.is_blocked? } || []
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
