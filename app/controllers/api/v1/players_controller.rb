# frozen_string_literal: true

module Api
  module V1
    class PlayersController < Api::V1::ApplicationController
      before_action :set_player, only: %i[show update destroy add_to_round add_to_team match_stats]
      def index
        players = if params[:championship_id]
                    Player.in_championship(params[:championship_id])
                  else
                    Player.all
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
        round = Round.find(params[:round_id])

        @player.rounds << round unless @player.rounds.include?(round)

        render json: @player
      end

      def add_to_team
        team = Team.find(params[:team_id])

        @player.teams << team unless @player.teams.include?(team)

        render json: @player
      end

      def match_stats
        team = Team.find(params[:team_id])
        round = Round.find(params[:round_id])
        match = Match.find(params[:match_id])
        @goals_in_match = @player.goals_in_match(match.id)
        @own_goals_in_match = @player.own_goals_in_match(match.id)
        @assists_in_match = @player.assists_in_match(match.id)
        @total_matches_for_a_team = @player.total_matches_for_a_team(team.id, round.id)
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
        params.require(:player).permit(:name, player_teams_attributes: %i[id team_id _destroy],
                                              player_rounds_attributes: %i[id round_id _destroy])
      end
    end
  end
end
