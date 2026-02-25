# frozen_string_literal: true

module Api
  module V1
    class TeamsController < Api::V1::ApplicationController
      before_action :set_team, only: %i[update destroy toggle_block]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        base_relation_scope = params[:round_id] ? Team.where(round_id: params[:round_id]) : Team.all
        base_query = Teams::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        collection = Teams::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
      end

      def show
        @team = Teams::FindQuery.new(id: params[:id], user_id: current_user.id).call
      end

      def create
        @team = Team.new(team_params)
        if @team.save
          render json: TeamPresenter.new(@team).as_json, status: :created
        else
          render json: @team.errors, status: :unprocessable_content
        end
      end

      def update
        if @team.update(team_params)
          render json: TeamPresenter.new(@team).as_json
        else
          render json: @team.errors, status: :unprocessable_content
        end
      rescue ActiveRecord::RecordNotDestroyed => e
        message = e.record.respond_to?(:errors) && e.record.errors.any? ? e.record.errors.full_messages.join : e.message
        render json: { errors: [message] }, status: :unprocessable_content
      end

      def destroy
        @team.destroy
        head :no_content
      end

      def toggle_block
        @team.update!(is_blocked: !@team.is_blocked)
        render json: { team_id: @team.id, is_blocked: @team.is_blocked }, status: :ok
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      private

      def set_team
        @team = Team
                .joins(round: :championship)
                .where(championships: { user_id: current_user.id })
                .find(params[:id])
      end

      def team_params
        params.require(:team).permit(:name, :round_id, player_teams_attributes: %i[id player_id _destroy])
      end
    end
  end
end
