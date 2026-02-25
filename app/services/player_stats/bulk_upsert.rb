# frozen_string_literal: true

module PlayerStats
  class BulkUpsert < ApplicationService
    class InvalidAssistsError < StandardError; end
    class InvalidGoalkeeperError < StandardError; end

    def initialize(match_id:, payload:)
      @match_id = match_id
      @payload = Array(payload)
    end

    def call
      validate_assists_rules!
      validate_goalkeeper_rules!
      ActiveRecord::Base.transaction do
        PlayerStat.where(match_id: match_id).delete_all
        creation_order.each do |stat_params|
          PlayerStat.create!(build_attributes(stat_params))
        end
      end

      PlayerStats::CollectionQuery.new(relation: PlayerStat.where(match_id: match_id)).call.to_a
    end

    private

    attr_reader :match_id, :payload

    # Create goal scorers before assist-only rows so model validation (assists ≤ team goals) sees existing goals.
    def creation_order
      payload.sort_by do |row|
        h = (row.is_a?(Hash) ? row : row.to_h).symbolize_keys
        goals = h[:goals].to_i
        assists = h[:assists].to_i
        # 0 = first: has goals; 1 = then: has assists only; 2 = last: neither
        order_key = if goals.positive?
                      0
                    elsif assists.positive?
                      1
                    else
                      2
                    end
        [h[:team_id], order_key]
      end
    end

    def build_attributes(stat_params)
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

    def validate_goalkeeper_rules!
      normalized_rows = payload.map { |row| row.is_a?(Hash) ? row : row.to_h }
      return if LeagueEngine::Rules::GoalkeeperRule.valid_configuration?(normalized_rows)

      raise InvalidGoalkeeperError,
            I18n.t('activerecord.errors.models.player_stat.attributes.was_goalkeeper.goalkeeper_not_line_player')
    end
  end
end
