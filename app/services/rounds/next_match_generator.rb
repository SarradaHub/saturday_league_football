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
      teams_ordered = round.teams.order(:created_at).to_a
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
          full_next = queue.select { |team| full_team?(team) }
          if index.zero? && full_next.size == 1
            return {
              needs_winner_selection: true,
              candidates: [standing, incoming],
              next_opponent: full_next.first,
              queue:,
              last_match: match
            }
          end

          if full_next.size >= 2
            queue = queue + [standing, incoming]
            standing = queue.shift
            incoming = queue.shift
          else
            queue = queue + [standing]
            standing = incoming
            incoming = queue.shift
          end
        else
          winner = resolve_winner(match, standing, incoming)
          loser = winner.id == standing.id ? incoming : standing
          queue = queue + [loser]
          standing = winner
          incoming = queue.shift
        end
      end

      raise NotEnoughTeamsError, 'Not enough teams to create a match' if standing.blank? || incoming.blank?

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

      queue = rebuild_queue(teams_ordered, [standing, incoming], queue)
      [standing, incoming, queue]
    end

    def rebuild_queue(teams_ordered, active_teams, current_queue)
      active_ids = active_teams.compact.map(&:id)
      base_queue = current_queue.presence || teams_ordered
      cleaned = base_queue.reject { |team| active_ids.include?(team.id) }

      # Ensure all teams are present in order
      existing_ids = cleaned.map(&:id)
      teams_ordered.each do |team|
        next if active_ids.include?(team.id) || existing_ids.include?(team.id)

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
        }
      }
    end

    def winner_selection_payload(state)
      {
        needs_winner_selection: true,
        reason: 'first_match_draw_one_next_team',
        candidates: state[:candidates].map { |team| TeamSerializer.new(team).as_json },
        next_opponent: TeamSerializer.new(state[:next_opponent]).as_json
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

      fill_team_from_loser!(incoming, loser) if loser.present?

      Match.create!(
        round: round,
        name: match_name(winner, incoming),
        team_1: winner,
        team_2: incoming
      )
    end

    def create_match_from_state(state)
      standing = state[:standing]
      incoming = state[:incoming]
      last_match = state[:last_match]
      loser = loser_from_match(last_match, standing, incoming)

      fill_team_from_loser!(incoming, loser) if loser.present?

      Match.create!(
        round: round,
        name: match_name(standing, incoming),
        team_1: standing,
        team_2: incoming
      )
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

    def match_name(team_1, team_2)
      "#{team_1.name} vs #{team_2.name}"
    end
  end
end
