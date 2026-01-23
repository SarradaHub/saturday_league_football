# frozen_string_literal: true

module PlayerStats
  class BulkUpsert < ApplicationService
    class InvalidAssistsError < StandardError; end

    def initialize(match_id:, payload:)
      @match_id = match_id
      @payload = Array(payload)
    end

    def call
      validate_assists_rules!
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
      # Convert to hash and symbolize keys
      attributes = stat_params.is_a?(Hash) ? stat_params.symbolize_keys : stat_params.to_h.symbolize_keys
      attributes.slice(:goals, :own_goals, :assists, :was_goalkeeper, :player_id, :team_id)
                .merge(match_id: match_id)
    end

    def validate_assists_rules!
      payload.each do |row|
        h = row.is_a?(Hash) ? row : row.to_h
        h = h.symbolize_keys
        goals = h[:goals].to_i
        assists = h[:assists].to_i
        own_goals = h[:own_goals].to_i
        if own_goals.positive? && assists.positive?
          raise InvalidAssistsError, I18n.t('activerecord.errors.models.player_stat.attributes.assists.no_assists_on_own_goals')
        end
      end

      by_team = payload.group_by { |row| (row.is_a?(Hash) ? row : row.to_h).symbolize_keys[:team_id] }
      by_team.each do |_team_id, rows|
        total_goals = rows.sum { |r| (r.is_a?(Hash) ? r : r.to_h).dig(:goals).to_i }
        total_assists = rows.sum { |r| (r.is_a?(Hash) ? r : r.to_h).dig(:assists).to_i }
        next if total_assists <= total_goals

        raise InvalidAssistsError, I18n.t('activerecord.errors.models.player_stat.attributes.assists.assists_require_goals')
      end
    end
  end
end
