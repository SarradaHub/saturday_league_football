# frozen_string_literal: true

module Api
  module V1
    class PlayersController < Api::V1::ApplicationController
      before_action :set_player, only: %i[show update destroy]
      def index
        @players = Player.all
      end

      def show; end

      def create
        @player = Player.new(player_params)
        if @player.save
          render json: @player, status: :created, location: @player
        else
          render json: @player.errors, status: :unprocessable_entity
        end
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
        params.require(:player).permit(:name, player_teams_attributes: %i[id team_id _destroy])
      end
    end
  end
end
