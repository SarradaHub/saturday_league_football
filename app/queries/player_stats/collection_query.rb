# frozen_string_literal: true

module PlayerStats
  class CollectionQuery < ApplicationQuery
    def initialize(relation: PlayerStat.all, includes: [], page: nil, per_page: nil, user_id: nil)
      @relation = relation
      @includes = includes
      @page = page
      @per_page = per_page
      @user_id = user_id
    end

    def call
      scope = relation.select(
        :id,
        :goals,
        :own_goals,
        :assists,
        :was_goalkeeper,
        :match_id,
        :team_id,
        :player_id,
        :created_at,
        :updated_at
      )

      if user_id.present?
        scope = scope.joins(match: { round: :championship })
                      .where(championships: { user_id: user_id })
      end

      if includes.any?
        scope = apply_includes(scope, includes)
      else
        scope = scope.includes(:player, :team, :match)
      end

      if page && per_page
        offset = (page - 1) * per_page
        scope = scope.limit(per_page).offset(offset)
      end

      scope
    end

    private

    attr_reader :relation, :includes, :page, :per_page, :user_id

    def apply_includes(scope, includes_list)
      includes_hash = {}
      includes_list.each do |include_str|
        parts = include_str.split('.').map(&:to_sym)
        current = includes_hash

        parts.each_with_index do |part, index|
          if index == parts.length - 1
            current[part] = {}
          else
            current[part] ||= {}
            current = current[part]
          end
        end
      end

      if includes_hash.any?
        scope.includes(includes_hash)
      else
        scope.includes(includes_list.map(&:to_sym))
      end
    end
  end
end
