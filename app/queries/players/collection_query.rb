# frozen_string_literal: true

module Players
  class CollectionQuery < ApplicationQuery
    def initialize(championship_id: nil, round_id: nil, includes: [], page: nil, per_page: nil, user_id: nil)
      @championship_id = championship_id
      @round_id = round_id
      @includes = includes
      @page = page
      @per_page = per_page
      @user_id = user_id
    end

    def call
      scope = Player.all
      scope = scope.in_championship(championship_id) if championship_id.present?

      if round_id.present? || user_id.present?
        scope = scope.joins(player_rounds: { round: :championship })
        
        conditions = {}
        conditions[:player_rounds] = { round_id: round_id } if round_id.present?
        conditions[:championships] = { user_id: user_id } if user_id.present?
        
        scope = scope.where(conditions) if conditions.any?
        scope = scope.distinct
      end

      if includes.any?
        scope = apply_includes(scope, includes)
      else
        scope = scope.includes(:player_stats, { player_rounds: :round })
      end

      scope = scope.order(Player.arel_table[:first_name], Player.arel_table[:last_name], Player.arel_table[:nickname])

      if page && per_page
        offset = (page - 1) * per_page
        scope = scope.limit(per_page).offset(offset)
      end

      scope
    end

    private

    attr_reader :championship_id, :round_id, :includes, :page, :per_page, :user_id

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
