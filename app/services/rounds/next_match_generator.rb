# frozen_string_literal: true

module Rounds
  class NextMatchGenerator < ApplicationService
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
      round.reload
      round.association(:matches).reload
      round.association(:teams).reload
      round.association(:player_rounds).reload
      teams_ordered = round.teams.not_blocked.order(:created_at).to_a
      if teams_ordered.size < 2
        total = round.teams.count
        blocked = round.teams.where(is_blocked: true).count
        msg = if total < 2
                "A rodada precisa de pelo menos 2 times (atual: #{total}). Crie times."
        elsif blocked.positive?
          "Não há times suficientes disponíveis: #{total - blocked} de #{total} não estão bloqueados. Desbloqueie times ou rebalanceie."
        else
          'Não existe times suficientes para criar uma partida'
        end
        raise NotEnoughTeamsError, msg
      end

      completed_matches = round.matches.includes(:team_1, :team_2, :winning_team)
                               .select { |match| match.draw.in?([true, false]) || match.winning_team_id.present? }
                               .sort_by(&:created_at)

      queue = teams_ordered.dup
      standing = queue.shift
      incoming = queue.shift

      last_draw_effective_loser = nil
      last_draw_both_redistribute = false

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

          # Reload player_rounds so field_players_count sees current DB state (e.g. in tests)
          round.association(:player_rounds).reload
          full_next = queue.select { |team| team.present? && full_team?(team) && !team.is_blocked? }

          if index.zero? && completed_matches.size == 1 && full_next.size < 2
            next_opponent = queue.compact.reject { |team| team.is_blocked? }.min_by { |t| t.created_at || Time.current }
            return {
              needs_winner_selection: true,
              reason: 'first_match_draw',
              candidates: [standing, incoming],
              next_opponent: next_opponent,
              queue:,
              last_match: match
            }
          end

          # First match draw with 2+ full teams in queue: advance to them; or more matches exist: fall through

          if full_next.size >= 2
            queue = queue + [standing, incoming].compact.reject { |team| team.is_blocked? }
            full_next_sorted = full_next.sort_by { |t| t.created_at || Time.current }
            standing = full_next_sorted[0]
            incoming = full_next_sorted[1]
            queue = queue.reject { |team| team.id == standing.id || team.id == incoming.id }

            last_draw_both_redistribute = (index == completed_matches.size - 1)
            last_draw_effective_loser = nil if last_draw_both_redistribute
          else
            queue = queue + [standing].compact.reject { |team| team.is_blocked? }
            standing = incoming
            incoming = queue.shift

            last_draw_effective_loser = if index == completed_matches.size - 1
                                          match.team_1
                                        else
                                          last_draw_effective_loser
                                        end
            last_draw_both_redistribute = false if index == completed_matches.size - 1
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

      if standing.blank? || incoming.blank?
        raise NotEnoughTeamsError,
              'Não foi possível definir o próximo par de times (standing ou incoming vazio após processar as partidas).'
      end

      queue = queue.compact.reject { |team| team.nil? || team.is_blocked? }
                   .sort_by { |t| t.created_at || Time.current }

      {
        standing: standing,
        incoming: incoming,
        queue: queue,
        last_match: completed_matches.last,
        last_match_draw_effective_loser: last_draw_effective_loser,
        last_match_draw_both_redistribute: last_draw_both_redistribute
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

    def full_team?(team)
      TeamFormationRules.full_team?(round, team, round.championship)
    end

    def field_players_count(team)
      TeamFormationRules.field_players_count(round, team)
    end

    def slots_per_team
      TeamFormationRules.slots_per_team(round.championship)
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
        reason: state[:reason] || 'first_match_draw_one_next_team',
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

      if incoming.blank?
        raise NotEnoughTeamsError,
              'Próximo adversário (next_opponent) não encontrado para criar a partida após seleção de vencedor.'
      end

      match = Match.create!(
        round: round,
        name: match_name(winner, incoming),
        team_1: winner,
        team_2: incoming
      )

      new_state = compute_state
      queue_after = new_state[:queue] || []
      redistribute_losing_team_players!(loser, queue_after, incoming: new_state[:incoming], last_match: state[:last_match]) if loser.present?

      final_state = compute_state
      updated_queue = build_queue_for_payload(final_state)

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

      queue = state[:queue] || []

      if match_result(last_match) == :draw
        if state[:last_match_draw_both_redistribute]
          redistribute_both_teams_from_draw!(last_match, queue, incoming: state[:incoming])
        elsif state[:last_match_draw_effective_loser].present?
          redistribute_losing_team_players!(state[:last_match_draw_effective_loser], queue, incoming: state[:incoming], last_match:)
        end
      else
        loser = loser_from_match(last_match, state[:standing], state[:incoming])
        redistribute_losing_team_players!(loser, queue, incoming: state[:incoming], last_match:) if loser.present?
      end
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

      current_size = field_players_count(target_team)
      missing_slots = [slots - current_size, 0].max
      return if missing_slots.zero?

      field_player_ids = field_eligible_player_ids
      target_player_ids = target_team.players.pluck(:id)
      losing_team.player_teams.order(:created_at).includes(:player).each do |player_team|
        break if missing_slots.zero?

        player = player_team.player
        next if target_player_ids.include?(player.id)
        next unless field_player_ids.include?(player.id)

        find_or_create_or_restore_player_team!(player: player, team: target_team)
        target_player_ids << player.id
        missing_slots -= 1
      end
    end

    def redistribute_losing_team_players!(losing_team, queue, incoming: nil, last_match: nil)
      return nil if losing_team.blank?

      losing_team.update!(is_blocked: true)

      losing_players = losing_team.player_teams
                                  .includes(:player)
                                  .order(:created_at)
                                  .map(&:player)
                                  .compact

      active_player_ids = round.teams
                               .not_blocked
                               .where.not(id: losing_team.id)
                               .joins(:players)
                               .pluck('players.id')
                               .uniq
      losing_players = losing_players.reject { |player| active_player_ids.include?(player.id) }
      # Ordem de redistribuição: estritamente a ordem de inscrição no time (player_teams.created_at).

      return nil if losing_players.empty?

      slots = slots_per_team
      return nil unless slots.positive?

      field_player_ids = field_eligible_player_ids(match: last_match)
      losing_field = losing_players.select { |p| field_player_ids.include?(p.id) }
      losing_goalkeepers = losing_players.reject { |p| field_player_ids.include?(p.id) }
      remaining_field = losing_field.dup

      fill_team_with_losing_players!(incoming, remaining_field, slots) if incoming.present? && !incoming.is_blocked?

      queue.each do |team|
        next if team.id == losing_team.id || team.is_blocked? || full_team?(team)
        fill_team_with_losing_players!(team, remaining_field, slots)
        break if remaining_field.empty?
      end

      new_team = nil
      if remaining_field.any?
        new_team = create_new_team_with_players(remaining_field)
      end

      new_team
    end

    def redistribute_both_teams_from_draw!(match, queue, incoming: nil)
      teams = [match.team_1, match.team_2].compact
      return if teams.empty?

      teams.each do |team|
        team.update!(is_blocked: true)
      end

      active_player_ids = round.teams
                               .not_blocked
                               .joins(:players)
                               .pluck('players.id')
                               .uniq

      players_team_1 = ordered_players_for_team(match.team_1, active_player_ids)
      players_team_2 = ordered_players_for_team(match.team_2, active_player_ids)

      losing_players = players_team_1 + players_team_2
      return if losing_players.empty?

      slots = slots_per_team
      return unless slots.positive?

      field_player_ids = field_eligible_player_ids(match:)
      losing_field = losing_players.select { |p| field_player_ids.include?(p.id) }
      remaining_field = losing_field.dup

      fill_team_with_losing_players!(incoming, remaining_field, slots) if incoming.present? && !incoming.is_blocked?

      queue.each do |team|
        next if teams.map(&:id).include?(team.id) || team.is_blocked? || full_team?(team)
        fill_team_with_losing_players!(team, remaining_field, slots)
        break if remaining_field.empty?
      end

      if remaining_field.any?
        create_new_team_with_players(remaining_field)
      end
    end

    def ordered_players_for_team(team, active_player_ids)
      return [] if team.blank?

      players = team.player_teams
                    .includes(:player)
                    .order(:created_at)
                    .map(&:player)
                    .compact

      players = players.reject { |player| active_player_ids.include?(player.id) }
      # Ordem: inscrição no time (player_teams.created_at), sem reordenar por player_round.
      players
    end

    def fill_team_with_losing_players!(team, remaining_players, target_slots)
      return if team.blank? || remaining_players.empty?

      team.reload
      current_size = field_players_count(team)
      missing_slots = [target_slots - current_size, 0].max
      return if missing_slots.zero?

      # Query DB directly to avoid association cache; team.players can be stale.
      target_player_ids = PlayerTeam.where(team_id: team.id).pluck(:player_id)
      players_to_move = remaining_players.select { |player| !target_player_ids.include?(player.id) }.first(missing_slots)

      players_to_move.each do |player|
        find_or_create_or_restore_player_team!(player: player, team: team)
        remaining_players.delete(player)
      end
    end

    def field_eligible_player_ids(match: nil)
      base_ids = round.player_rounds.where(blocked: false, goalkeeper_only: false).pluck(:player_id)
      return base_ids if base_ids.empty? || match.blank?

      goalkeeper_ids = PlayerStat.where(match_id: match.id, was_goalkeeper: true).pluck(:player_id)
      base_ids - goalkeeper_ids
    end

    def create_new_team_with_players(players)
      existing_names = round.teams.pluck(:name)
      team_name = TeamFormationRules.unique_team_name(existing_names.length + 1, existing_names)

      new_team = round.teams.create!(name: team_name)

      players.each do |player|
        find_or_create_or_restore_player_team!(player: player, team: new_team)
      end

      new_team
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

    # Finds existing PlayerTeam (including soft-deleted), restores if deleted, or creates new.
    # Handles the case where a player was removed from a team (PlayerTeam soft-deleted) and
    # we need to add them back during redistribution.
    def find_or_create_or_restore_player_team!(player:, team:)
      player_team = PlayerTeam.with_deleted.find_by(player_id: player.id, team_id: team.id)
      if player_team
        player_team.restore if player_team.deleted?
      else
        PlayerTeam.create!(player: player, team: team)
      end
    end
  end
end
