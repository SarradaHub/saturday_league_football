# frozen_string_literal: true

module Api
  module V1
    class RoundsController < Api::V1::ApplicationController
      before_action :set_round, only: %i[show update destroy]
      def index
        @rounds = Round.includes(:players).order(round_date: :desc).all
      end

      def show; end

      def create
        @round = Round.new(round_params)
        if @round.save
          render json: @round, status: :created
        else
          render json: @round.errors, status: :unprocessable_entity
        end
      end

      def update
        if @round.update(round_params)
          render json: @round
        else
          render json: @round.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @round.destroy
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
