# frozen_string_literal: true

module Api
  module V1
    class RoundsController < Api::V1::ApplicationController
      before_action :set_round, only: %i[update destroy]
      def index
        @rounds = Rounds::CollectionQuery.new.call
      end

      def show
        @round = Rounds::FindQuery.new(id: params[:id]).call
      end

      def create
        @round = Round.new(round_params)
        if @round.save
          render json: RoundPresenter.new(@round).as_json, status: :created
        else
          render json: @round.errors, status: :unprocessable_entity
        end
      end

      def update
        if @round.update(round_params)
          render json: RoundPresenter.new(@round).as_json
        else
          render json: @round.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @round.destroy
        head :no_content
      end

      private

      def set_round
        @round = Round
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
    end
  end
end
