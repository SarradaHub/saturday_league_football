# frozen_string_literal: true

module Api
  module V1
    class PlayersController < Api::V1::ApplicationController
      before_action :set_player, only: %i[show update destroy]
      def index
        if params[:championship_id]
          players = Player.in_championship(params[:championship_id])
        else
          players = Player.all
        end
        render json: players
      end

      def show; end

      def create
        @player = Player.new(player_params)
        if @player.save
          render json: @player, status: :created
        else
          render json: @player.errors, status: :unprocessable_entity
        end
      end

      def add_to_round
        player = Player.find(params[:id])
        round = Round.find(params[:round_id])

        unless player.rounds.include?(round)
          player.rounds << round
        end

        render json: player
      end

      def update
        if @player.update(player_params)
          render json: @player
        else
          render json: @player.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @player.destroy
      end

      private

      def set_player
        @player = Player.find(params[:id])
      end

      def player_params
        params.require(:player).permit(:name, player_teams_attributes: %i[id team_id _destroy], player_rounds_attributes: %i[id round_id _destroy])
      end
    end
  end
end
