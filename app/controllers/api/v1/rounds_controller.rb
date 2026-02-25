# frozen_string_literal: true

module Api
  module V1
    class RoundsController < Api::V1::ApplicationController
      before_action :set_round, only: %i[update destroy]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        base_query = Rounds::CollectionQuery.new(
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        collection = Rounds::CollectionQuery.new(
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, presenter_class: RoundPresenter, base_relation: base_relation)
      end

      def show
        @round = Rounds::FindQuery.new(id: params[:id], user_id: current_user.id).call
        round_json = RoundPresenter.new(@round).as_json
        allowed_fields = parse_fields
        round_json = filter_fields(round_json, allowed_fields) if allowed_fields.present?
        render json: round_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Round not found' }, status: :not_found
      end

      def summary
        @round = Rounds::FindQuery.new(id: params[:id], user_id: current_user.id).call
        render json: RoundSummaryPresenter.new(@round).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Round not found' }, status: :not_found
      end

      def create
        @round = Round.new(round_params)
        if @round.save
          render json: RoundPresenter.new(@round).as_json, status: :created
        else
          render json: @round.errors, status: :unprocessable_content
        end
      end

      def update
        if @round.update(round_params)
          render json: RoundPresenter.new(@round).as_json
        else
          render json: @round.errors, status: :unprocessable_content
        end
      end

      def destroy
        if @round.destroy
          head :no_content
        else
          message = @round.errors.full_messages.join(", ")
          render json: {
            error: {
              code: "round_has_matches",
              message: message.presence || "Não é possível excluir rodada com partidas associadas. Exclua as partidas primeiro."
            }
          }, status: :unprocessable_content
        end
      end

      def statistics
        stats = Rounds::RoundStatistics.call(round_id: params[:id])
        render json: stats
      end

      def suggest_next_match
        round = find_round_for_sequence
        suggestion = LeagueEngine::Engine.suggest_next_match(round: round)
        render json: suggestion
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      def create_next_match
        round = find_round_for_sequence
        result = LeagueEngine::Engine.create_next_match(
          round: round,
          winner_team_id: params[:winner_team_id]
        )

        if result.is_a?(Hash) && result[:match]
          render json: {
            match: MatchPresenter.new(result[:match]).as_json,
            queue: result[:queue]
          }, status: :created
        else
          render json: MatchPresenter.new(result).as_json, status: :created
        end
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      def substitute_player
        round = find_round_for_sequence
        result = LeagueEngine::Engine.replace_in_round(
          round: round,
          player_id: params[:player_id],
          match_id: params[:match_id]
        )
        render json: result, status: :ok
      rescue Substitutions::ReplacePlayer::PlayerNotInRoundError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue Substitutions::ReplacePlayer::NoAvailablePlayerError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      def remove_player
        round = find_round_for_sequence
        player_round = round.player_rounds.find_by!(player_id: params[:player_id])
        player_round.destroy
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { errors: ['Jogador não encontrado nesta rodada'] }, status: :unprocessable_content
      end

      def toggle_player_block
        round = find_round_for_sequence
        player_round = round.player_rounds.find_by!(player_id: params[:player_id])
        player_round.update!(blocked: !player_round.blocked)
        render json: { player_round_id: player_round.id, blocked: player_round.blocked }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: ['Jogador não encontrado nesta rodada'] }, status: :unprocessable_content
      end

      def rebalance_teams
        round = find_round_for_sequence
        players_before = round.players.count
        teams_before = round.teams.count

        Rounds::RoundTeamGenerator.call(round, active_teams_only: true)

        round.reload
        players_after = round.players.count
        teams_after = round.teams.count

        team_distribution = round.teams.order(:created_at).map do |team|
          {
            id: team.id,
            name: team.name,
            players_count: team.players_count || team.players.count
          }
        end

        render json: {
          message: 'Times rebalanceados com sucesso',
          teams_before: teams_before,
          teams_after: teams_after,
          players_before: players_before,
          players_after: players_after,
          distribution: team_distribution
        }, status: :ok
      rescue Rounds::RoundTeamGenerator::PlayerLimitError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      private

      def cacheable_resource?
        request.get? && %w[index summary statistics].include?(action_name)
      end

      def set_round
        @round = Round
                 .joins(:championship)
                 .where(championships: { user_id: current_user.id })
                 .includes(
                   matches: %i[team_1 team_2],
                   teams: { player_teams: { player: :player_stats } },
                   player_rounds: { player: :player_stats }
                 )
                 .find(params[:id])

        player_ids = @round.player_rounds.map(&:player_id).uniq

        @players = Player.includes(:player_stats, :rounds).where(id: player_ids)

        @player_stats_totals =
          PlayerStat.where(player_id: player_ids)
                    .group(:player_id)
                    .pluck(
                      :player_id,
                      Arel.sql('COALESCE(SUM(goals), 0)'),
                      Arel.sql('COALESCE(SUM(assists), 0)'),
                      Arel.sql('COALESCE(SUM(own_goals), 0)')
                    )
                    .each_with_object({}) do |(player_id, goals, assists, own_goals), totals|
                      totals[player_id] = {
                        goals: goals,
                        assists: assists,
                        own_goals: own_goals
                      }
                    end
      end

      def round_params
        params.require(:round).permit(:name, :round_date, :championship_id)
      end

      def find_round_for_sequence
        Rounds::FindQuery.new(id: params[:id], user_id: current_user.id).call
      end
    end
  end
end
