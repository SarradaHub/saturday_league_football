# frozen_string_literal: true

module Api
  module V1
    class PlayerStatsController < Api::V1::ApplicationController
      before_action :set_player_stat, only: %i[show update destroy]

      def index
        @player_stats = PlayerStat.all
        render json: @player_stats
      end

      def show
        render json: @player_stat
      end

      def create
        @player_stat = PlayerStat.new(player_stat_params)
        if @player_stat.save
          render json: @player_stat, status: :created
        else
          render json: { errors: @player_stat.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @player_stat.update(player_stat_params)
          render json: @player_stat
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
        match_id = params[:match_id]
        @player_stats = PlayerStat.where(match_id: match_id).includes(:player, :team)
        render json: @player_stats
      end

      # Bulk create/update player stats for a match
      def bulk_update
        match_id = params[:match_id]
        player_stats_params = params[:player_stats]

        ActiveRecord::Base.transaction do
          # Delete existing player stats for this match
          PlayerStat.where(match_id: match_id).destroy_all

          # Create new player stats
          player_stats_params.each do |stat_params|
            PlayerStat.create!(
              goals: stat_params[:goals],
              own_goals: stat_params[:own_goals],
              assists: stat_params[:assists],
              was_goalkeeper: stat_params[:was_goalkeeper],
              player_id: stat_params[:player_id],
              team_id: stat_params[:team_id],
              match_id: match_id
            )
          end
        end

        # Return updated player stats for the match
        @player_stats = PlayerStat.where(match_id: match_id).includes(:player, :team)
        render json: @player_stats
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
    end
  end
end
