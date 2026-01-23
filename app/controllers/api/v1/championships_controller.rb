# frozen_string_literal: true

module Api
  module V1
    class ChampionshipsController < Api::V1::ApplicationController
      before_action :set_championship, only: %i[update destroy]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        # Get base relation for count
        base_query = Championships::CollectionQuery.new(includes: includes_list, page: nil, per_page: nil)
        base_relation = base_query.call
        # Get paginated collection
        collection = Championships::CollectionQuery.new(
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page]
        ).call
        render_collection(collection, presenter_class: ChampionshipPresenter, base_relation: base_relation)
      end

      def show
        includes_list = parse_includes
        @championship = Championships::FindQuery.new(id: params[:id], includes: includes_list).call
        championship_json = ChampionshipPresenter.new(@championship).as_json
        allowed_fields = parse_fields
        championship_json = filter_fields(championship_json, allowed_fields) if allowed_fields.present?
        render json: championship_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Championship not found' }, status: :not_found
      end

      def create
        @championship = Championship.new(championship_params)
        if @championship.save
          render json: ChampionshipPresenter.new(@championship).as_json, status: :created
        else
          render json: @championship.errors, status: :unprocessable_content
        end
      end

      def update
        if @championship.update(championship_params)
          render json: ChampionshipPresenter.new(@championship).as_json
        else
          render json: @championship.errors, status: :unprocessable_content
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
        params.require(:championship).permit(:name, :description, :min_players_per_team, :max_players_per_team)
      end
    end
  end
end
