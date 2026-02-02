# frozen_string_literal: true

module Api
  module V1
    class RoundsController < Api::V1::ApplicationController
      before_action :set_round, only: %i[update destroy]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        # Get base relation for count
        base_query = Rounds::CollectionQuery.new(
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        # Get paginated collection
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
        @round.destroy
        head :no_content
      end

      def statistics
        stats = RoundStatistics.call(round_id: params[:id])
        render json: stats
      end

      def suggest_next_match
        round = find_round_for_sequence
        suggestion = Rounds::NextMatchGenerator.call(round: round)
        render json: suggestion
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      def create_next_match
        round = find_round_for_sequence
        result = Rounds::NextMatchGenerator.call(
          round: round,
          winner_team_id: params[:winner_team_id],
          create_match: true
        )
        
        # Result can be a Match (old format) or a hash with match and queue (new format)
        if result.is_a?(Hash) && result[:match]
          render json: {
            match: MatchPresenter.new(result[:match]).as_json,
            queue: result[:queue]
          }, status: :created
        else
          # Fallback for old format (should not happen, but keeping for safety)
          render json: MatchPresenter.new(result).as_json, status: :created
        end
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      private

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
