# frozen_string_literal: true

module Api
  module V1
    class TeamsController < Api::V1::ApplicationController
      before_action :set_team, only: %i[update destroy]
      def index
        @teams = Teams::CollectionQuery.new.call
      end

      def show
        @team = Teams::FindQuery.new(id: params[:id]).call
      end

      def create
        @team = Team.new(team_params)
        if @team.save
          render json: TeamPresenter.new(@team).as_json, status: :created
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      def update
        if @team.update(team_params)
          render json: TeamPresenter.new(@team).as_json
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @team.destroy
        head :no_content
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
