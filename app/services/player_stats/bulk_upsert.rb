# frozen_string_literal: true

module PlayerStats
  class BulkUpsert < ApplicationService
    def initialize(match_id:, payload:)
      @match_id = match_id
      @payload = Array(payload)
    end

    def call
      ActiveRecord::Base.transaction do
        PlayerStat.where(match_id: match_id).delete_all
        payload.each do |stat_params|
          PlayerStat.create!(build_attributes(stat_params))
        end
      end

      PlayerStats::CollectionQuery.call(relation: PlayerStat.where(match_id: match_id))
    end

    private

    attr_reader :match_id, :payload

    def build_attributes(stat_params)
      attributes = stat_params.to_h.symbolize_keys
      attributes.slice(:goals, :own_goals, :assists, :was_goalkeeper, :player_id, :team_id)
                .merge(match_id: match_id)
    end
  end
end
