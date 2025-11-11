# frozen_string_literal: true

module Api
  module V1
    class PlayerStatsController < Api::V1::ApplicationController
      before_action :set_player_stat, only: %i[show update destroy]

      def index
        player_stats = PlayerStats::CollectionQuery.call
        render json: serialize(player_stats)
      end

      def show
        render json: PlayerStatSerializer.new(@player_stat).as_json
      end

      def create
        @player_stat = PlayerStat.new(player_stat_params)
        if @player_stat.save
          render json: PlayerStatSerializer.new(@player_stat).as_json, status: :created
        else
          render json: { errors: @player_stat.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @player_stat.update(player_stat_params)
          render json: PlayerStatSerializer.new(@player_stat).as_json
        else
          render json: { errors: @player_stat.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @player_stat.destroy
        head :no_content
      end

      # Get player stats by match ID
      def by_match
        player_stats = PlayerStats::CollectionQuery.call(
          relation: PlayerStat.where(match_id: params[:match_id])
        )
        render json: serialize(player_stats)
      end

      # Bulk create/update player stats for a match
      def bulk_update
        stats = PlayerStats::BulkUpsert.call(
          match_id: params[:match_id],
          payload: params[:player_stats]
        )
        render json: serialize(stats)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_player_stat
        @player_stat = PlayerStat.find(params[:id])
      end

      def player_stat_params
        params.require(:player_stat).permit(:goals, :own_goals, :assists, :was_goalkeeper, :player_id, :team_id,
                                            :match_id)
      end

      def serialize(collection)
        Array(collection).map { |stat| PlayerStatSerializer.new(stat).as_json }
      end
    end
  end
end
