# frozen_string_literal: true

module Api
  module V1
    class MatchesController < Api::V1::ApplicationController
      before_action :set_match, only: %i[update destroy finalize]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        base_relation_scope = params[:round_id] ? Match.where(round_id: params[:round_id]) : Match.all
        # Get base relation for count
        base_query = Matches::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: nil,
          per_page: nil
        )
        base_relation = base_query.call
        # Get paginated collection
        collection = Matches::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page]
        ).call
        render_collection(collection, presenter_class: MatchPresenter, base_relation: base_relation)
      end

      def show
        @match = Matches::FindQuery.new(id: params[:id]).call
      end

      def create
        @match = Match.new(match_params)
        if @match.save
          render json: MatchPresenter.new(@match).as_json, status: :created
        else
          render json: @match.errors, status: :unprocessable_content
        end
      end

      def update
        if @match.update(match_params)
          render json: MatchPresenter.new(@match).as_json
        else
          render json: @match.errors, status: :unprocessable_content
        end
      end

      def destroy
        @match.destroy
        head :no_content
      end

      def finalize
        match = Matches::Finalize.call(match: @match)
        render json: MatchPresenter.new(match).as_json
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
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
