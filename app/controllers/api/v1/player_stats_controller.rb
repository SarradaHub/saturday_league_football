# frozen_string_literal: true

module Api
  module V1
    class PlayerStatsController < Api::V1::ApplicationController
      before_action :set_player_stat, only: %i[show update destroy]

      def index
        includes_list = parse_includes
        pagination = paginate_params
        base_query = PlayerStats::CollectionQuery.new(
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        collection = PlayerStats::CollectionQuery.new(
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, serializer_class: PlayerStatSerializer, base_relation: base_relation)
      end

      def show
        render json: PlayerStatSerializer.new(@player_stat).as_json
      end

      def create
        @player_stat = PlayerStat.new(player_stat_params)
        if @player_stat.save
          render json: PlayerStatSerializer.new(@player_stat).as_json, status: :created
        else
          render json: { errors: @player_stat.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @player_stat.update(player_stat_params)
          render json: PlayerStatSerializer.new(@player_stat).as_json
        else
          render json: { errors: @player_stat.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @player_stat.destroy
        head :no_content
      end
      def by_match
        includes_list = parse_includes
        pagination = paginate_params
        base_relation_scope = PlayerStat.where(match_id: params[:match_id])
        base_query = PlayerStats::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        collection = PlayerStats::CollectionQuery.new(
          relation: base_relation_scope,
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, serializer_class: PlayerStatSerializer, base_relation: base_relation)
      end

      def bulk_update
        permitted_stats = params[:player_stats]&.map do |stat_params|
          stat_params.permit(:player_id, :team_id, :goals, :assists, :own_goals, :was_goalkeeper).to_h
        end
        stats = LeagueEngine::Engine.bulk_update_player_stats(
          match_id: params[:match_id],
          payload: permitted_stats
        )
        render json: serialize(stats)
      rescue PlayerStats::BulkUpsert::InvalidAssistsError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue PlayerStats::BulkUpsert::InvalidGoalkeeperError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      def add_goalkeeper
        stat = LeagueEngine::Engine.add_goalkeeper(
          match_id: params[:match_id],
          team_id: params[:team_id],
          player_id: params[:player_id]
        )
        render json: PlayerStatSerializer.new(stat).as_json
      rescue PlayerStats::BulkUpsert::InvalidGoalkeeperError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
      rescue PlayerStats::AddGoalkeeper::MissingParamsError => e
        render json: { errors: [e.message] }, status: :unprocessable_content
      end

      private

      def set_player_stat
        @player_stat = PlayerStat
                       .joins(match: { round: :championship })
                       .where(championships: { user_id: current_user.id })
                       .find(params[:id])
      end

      def player_stat_params
        params.require(:player_stat).permit(:goals, :own_goals, :assists, :was_goalkeeper, :player_id, :team_id,
                                            :match_id)
      end

      def serialize(collection)
        Array(collection).map { |stat| PlayerStatSerializer.new(stat).as_json }
      end
    end
  end
end
