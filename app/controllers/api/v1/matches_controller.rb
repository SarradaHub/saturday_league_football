# frozen_string_literal: true

module Api
  module V1
    class MatchesController < Api::V1::ApplicationController
      before_action :set_match, only: %i[update destroy]
      def index
        @matches = Matches::CollectionQuery.new.call
      end

      def show
        @match = Matches::FindQuery.new(id: params[:id]).call
      end

      def create
        @match = Match.new(match_params)
        if @match.save
          render json: MatchPresenter.new(@match).as_json, status: :created
        else
          render json: @match.errors, status: :unprocessable_entity
        end
      end

      def update
        if @match.update(match_params)
          render json: MatchPresenter.new(@match).as_json
        else
          render json: @match.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @match.destroy
        head :no_content
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
