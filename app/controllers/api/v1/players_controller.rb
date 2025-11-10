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

        PlayerRound.find_or_create_by!(player: @player, round:)

        @round = Round.includes(:players, teams: :players).find(round.id)

        render 'api/v1/rounds/show', status: :ok
      end

      def add_to_team
        team = Team.find(params[:team_id])

        player_team = PlayerTeam.find_or_create_by(player: @player, team:)
        if player_team.persisted?
          @team = Team.includes(:players, :matches).find(team.id)

          render 'api/v1/teams/show', status: :ok
        else
          render json: { errors: player_team.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def match_stats
        find_related_entities
        calculate_match_statistics
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

      def find_related_entities
        @team = Team.find(params[:team_id])
        @round = Round.find(params[:round_id])
        @match = Match.find(params[:match_id])
      end

      def calculate_match_statistics
        @goals_in_match = @player.goals_in_match(@match.id)
        @own_goals_in_match = @player.own_goals_in_match(@match.id)
        @assists_in_match = @player.assists_in_match(@match.id)
        @total_matches_for_a_team = @player.total_matches_for_a_team(@team.id, @round.id)
      end
    end
  end
end
