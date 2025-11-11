# frozen_string_literal: true

module Api
  module V1
    class RoundsController < Api::V1::ApplicationController
      before_action :set_round, only: %i[update destroy]
      def index
        @rounds = Rounds::CollectionQuery.new.call
      end

      def show
        @round = Rounds::FindQuery.new(id: params[:id]).call
      end

      def create
        @round = Round.new(round_params)
        if @round.save
          render json: RoundPresenter.new(@round).as_json, status: :created
        else
          render json: @round.errors, status: :unprocessable_entity
        end
      end

      def update
        if @round.update(round_params)
          render json: RoundPresenter.new(@round).as_json
        else
          render json: @round.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @round.destroy
        head :no_content
      end

      private

      def set_round
        @round = Round.find(params[:id])
      end

      def round_params
        params.require(:round).permit(:name, :round_date, :championship_id)
      end
    end
  end
end
