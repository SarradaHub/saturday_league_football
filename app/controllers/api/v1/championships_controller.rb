# frozen_string_literal: true

module Api
  module V1
    class ChampionshipsController < Api::V1::ApplicationController
      before_action :set_championship, only: %i[update destroy]
      def index
        @championships = Championships::CollectionQuery.new.call
      end

      def show
        @championship = Championships::FindQuery.new(id: params[:id]).call
      end

      def create
        @championship = Championship.new(championship_params)
        if @championship.save
          render json: ChampionshipPresenter.new(@championship).as_json, status: :created
        else
          render json: @championship.errors, status: :unprocessable_entity
        end
      end

      def update
        if @championship.update(championship_params)
          render json: ChampionshipPresenter.new(@championship).as_json
        else
          render json: @championship.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @championship.destroy
        head :no_content
      end

      private

      def set_championship
        @championship = Championship.find(params[:id])
      end

      def championship_params
        params.require(:championship).permit(:name, :description)
      end
    end
  end
end
