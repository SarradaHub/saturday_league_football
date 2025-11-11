# frozen_string_literal: true

module Api
  module V1
    class PlayersController < Api::V1::ApplicationController
      before_action :set_player, only: %i[show update destroy add_to_round add_to_team match_stats]
      def index
        @players = Players::CollectionQuery.new(championship_id: params[:championship_id]).call
      end

      def show; end

      def create
        @player = Player.new(player_params)
        if @player.save
          render json: PlayerPresenter.new(@player).as_json, status: :created
        else
          render json: @player.errors, status: :unprocessable_entity
        end
      end

      def add_to_round
        player = Players::AddToRound.call(player: @player, round_id: params[:round_id])
        render json: PlayerPresenter.new(player).as_json
      end

      def add_to_team
        player = Players::AddToTeam.call(player: @player, team_id: params[:team_id])
        render json: PlayerPresenter.new(player).as_json
      end

      def match_stats
        render json: Players::MatchStatistics.call(
          player: @player,
          team: find_team,
          round: find_round,
          match: find_match
        )
      end

      def update
        if @player.update(player_params)
          render json: PlayerPresenter.new(@player).as_json
        else
          render json: @player.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @player.destroy
        head :no_content
      end

      private

      def set_player
        @player = Player.includes(:player_stats, :rounds, :teams).find(params[:id])
      end

      def player_params
        params.require(:player).permit(:name, player_teams_attributes: %i[id team_id _destroy],
                                              player_rounds_attributes: %i[id round_id _destroy])
      end

      def find_team
        Team.find(params[:team_id])
      end

      def find_round
        Round.find(params[:round_id])
      end

      def find_match
        Matches::FindQuery.new(id: params[:match_id]).call
      end
    end
  end
end
