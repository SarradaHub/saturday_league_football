# frozen_string_literal: true

module Api
  module V1
    class PlayerStatsController < Api::V1::ApplicationController
      before_action :set_player_stat, only: %i[show edit update destroy]

      def index
        @player_stats = PlayerStat.all
      end

      def show; end

      def new
        @player_stat = PlayerStat.new
      end

      def create
        @player_stat = PlayerStat.new(player_stat_params)
        if @player_stat.save
          redirect_to @player_stat, notice: 'PlayerStat was successfully created.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @player_stat.update(player_stat_params)
          redirect_to @player_stat, notice: 'PlayerStat was successfully updated.'
        else
          render :update, status: :unprocessable_entity
        end
      end

      def destroy
        @player_stat.destroy
        redirect_to player_stats_url, notice: 'PlayerStat was successfully destroyed.'
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
