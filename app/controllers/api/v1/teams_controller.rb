# frozen_string_literal: true

module Api
  module V1
    class TeamsController < Api::V1::ApplicationController
      before_action :set_team, only: %i[show update destroy]
      def index
        @teams = Team.all
      end

      def show; end

      def create
        @team = Team.new(team_params)
        if @team.save
          render json: @team, status: :created
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      def update
        if @team.update(team_params)
          render json: @team
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @team.destroy
      end

      private

      def set_team
        @team = Team.find(params[:id])
      end

      def team_params
        params.require(:team).permit(:name, :round_id, player_teams_attributes: %i[id player_id _destroy])
      end
    end
  end
end
