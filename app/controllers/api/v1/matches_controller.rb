# frozen_string_literal: true

module Api
  module V1
    class MatchesController < Api::V1::ApplicationController
      before_action :set_match, only: %i[update destroy finalize substitute_player]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        base_relation_scope = params[:round_id] ? Match.where(round_id: params[:round_id]) : Match.all
        base_query = Matches::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        collection = Matches::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, presenter_class: MatchPresenter, base_relation: base_relation)
      end

      def show
        @match = Matches::FindQuery.new(id: params[:id], user_id: current_user.id).call
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

      def substitute_player
        result = Matches::SubstitutePlayer.call(
          match: @match,
          player_id: params[:player_id],
          replacement_player_id: params[:replacement_player_id],
          team_id: params[:team_id]
        )
        render json: result, status: :ok
      rescue Matches::SubstitutePlayer::PlayerNotInTeamError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue Matches::SubstitutePlayer::ReplacementNotInRoundError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue Matches::SubstitutePlayer::ReplacementInMatchError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue Matches::SubstitutePlayer::InvalidTeamError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      private

      def set_match
        @match = Match
                 .joins(round: :championship)
                 .where(championships: { user_id: current_user.id })
                 .find(params[:id])
      end

      def match_params
        params.require(:match).permit(:name, :round_id, :team_1_id, :team_2_id, :winning_team_id, :draw)
      end
    end
  end
end
