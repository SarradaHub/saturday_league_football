# frozen_string_literal: true

module Api
  module V1
    class ChampionshipsController < Api::V1::ApplicationController
      before_action :set_championship, only: %i[update destroy]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        # Get base relation for count
        base_query = Championships::CollectionQuery.new(
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        # Get paginated collection
        collection = Championships::CollectionQuery.new(
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, presenter_class: ChampionshipPresenter, base_relation: base_relation)
      end

      def show
        includes_list = parse_includes
        @championship = Championships::FindQuery.new(id: params[:id], includes: includes_list, user_id: current_user.id).call
        presenter_options = {}
        presenter_options[:include_rounds] = true if includes_list.include?('rounds')
        presenter_options[:include_players] = true if includes_list.include?('players')
        championship_json = ChampionshipPresenter.new(@championship).as_json(presenter_options)
        allowed_fields = parse_fields
        championship_json = filter_fields(championship_json, allowed_fields) if allowed_fields.present?
        render json: championship_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Championship not found' }, status: :not_found
      end

      def create
        @championship = Championship.new(championship_params)
        @championship.user_id = current_user.id
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
        @championship = Championship.where(user_id: current_user.id).find(params[:id])
      end

      def championship_params
        params.require(:championship).permit(:name, :description, :min_players_per_team, :max_players_per_team)
      end
    end
  end
end
