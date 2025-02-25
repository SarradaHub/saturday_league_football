# frozen_string_literal: true

module Api
  module V1
    class MatchesController < Api::V1::ApplicationController
      before_action :set_match, only: %i[show update destroy]
      def index
        @matches = Match.all
      end

      def show
        @match = Match.includes(
          team_1: { players: :player_stats },
          team_2: { players: :player_stats }
        ).find(params[:id])
      end

      def create
        @match = Match.new(match_params)
        if @match.save
          render json: @match, status: :created, location: @match
        else
          render json: @match.errors, status: :unprocessable_entity
        end
      end

      def update
        if @match.update(match_params)
          render json: @match
        else
          render json: @match.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @match.destroy
      end

      private

      def set_match
        @match = Match.find(params[:id])
      end

      def match_params
        params.require(:match).permit(:name, :round_id, :team_1_id, :team_2_id, :winning_team_id, :draw)
      end
    end
  end
end
