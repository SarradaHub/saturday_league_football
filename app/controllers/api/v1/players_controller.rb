# frozen_string_literal: true

module Api
  module V1
    class PlayersController < Api::V1::ApplicationController
      before_action :set_player, only: %i[show update destroy add_to_round add_to_team match_stats summary]
      def index
        includes_list = parse_includes
        pagination = paginate_params
        base_query = Players::CollectionQuery.new(
          championship_id: params[:championship_id],
          round_id: params[:round_id],
          includes: includes_list,
          page: nil,
          per_page: nil,
          user_id: current_user.id
        )
        base_relation = base_query.call
        collection = Players::CollectionQuery.new(
          championship_id: params[:championship_id],
          round_id: params[:round_id],
          includes: includes_list,
          page: pagination[:page],
          per_page: pagination[:per_page],
          user_id: current_user.id
        ).call
        render_collection(collection, presenter_class: PlayerPresenter, base_relation: base_relation)
      end

      def show; end

      def create
        @player = Player.new(player_params)
        if @player.save
          render json: PlayerPresenter.new(@player).as_json, status: :created
        else
          render json: @player.errors, status: :unprocessable_content
        end
      end

      def add_to_round
        goalkeeper_only_param = ActiveModel::Type::Boolean.new.cast(params[:goalkeeper_only])
        goalkeeper_only_value = goalkeeper_only_param.nil? ? false : goalkeeper_only_param

        player = Players::AddToRound.call(
          player: @player,
          round_id: params[:round_id],
          goalkeeper_only: goalkeeper_only_value
        )
        player = Player.includes({ player_rounds: :round }).find(player.id)
        render json: PlayerPresenter.new(player).as_json
      end

      def add_to_team
        player = Players::AddToTeam.call(player: @player, team_id: params[:team_id])
        render json: PlayerPresenter.new(player).as_json
      end

      def match_stats
        render json: Players::MatchStatistics.call(
          player: @player,
          team: find_team,
          round: find_round,
          match: find_match
        )
      end

      def summary
        render json: PlayerSummaryPresenter.new(@player).as_json
      end

      def update
        if @player.update(player_params)
          render json: PlayerPresenter.new(@player).as_json
        else
          render json: @player.errors, status: :unprocessable_content
        end
      end

      def destroy
        @player.destroy
        head :no_content
      end

      private

      def set_player
        @player = Player
                  .joins(player_rounds: { round: :championship })
                  .where(championships: { user_id: current_user.id })
                  .distinct
                  .includes(:player_stats, :rounds, :teams)
                  .find(params[:id])
      end

      def player_params
        params.require(:player).permit(:first_name, :last_name, :nickname,
          player_teams_attributes: %i[id team_id _destroy],
          player_rounds_attributes: %i[id round_id _destroy])
      end

      def find_team
        Team.find(params[:team_id])
      end

      def find_round
        Round.find(params[:round_id])
      end

      def find_match
        Matches::FindQuery.new(id: params[:match_id]).call
      end
    end
  end
end
