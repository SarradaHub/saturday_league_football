# frozen_string_literal: true

module Championships
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Championship.all, includes: [], page: nil, per_page: nil, user_id: nil)
      @relation = relation
      @includes = includes
      @page = page
      @per_page = per_page
      @user_id = user_id
    end

    def call
      scope = relation.order(updated_at: :desc)
      
      # Filter by user_id if provided
      scope = scope.where(user_id: user_id) if user_id.present?

      # Apply includes - ChampionshipPresenter only serializes rounds/players if requested via include param
      # When players are included, we need to eager load their associations to avoid N+1
      if includes.any?
        includes_to_apply = includes.dup
        includes_hash = {}
        
        # Handle rounds
        if includes.include?('rounds')
          includes_hash[:rounds] = {}
        end
        
        # If players are requested, eager load through the correct path (rounds -> player_rounds -> player)
        # and also load player associations to avoid N+1 in PlayerPresenter
        if includes.include?('players')
          includes_hash[:rounds] ||= {}
          includes_hash[:rounds][:player_rounds] = { player: [:player_stats, :rounds, :teams] }
        end
        
        if includes_hash.any?
          scope = scope.includes(includes_hash)
        else
          scope = apply_includes(scope, includes_to_apply)
        end
      end
      # No default includes - ChampionshipPresenter only serializes what's requested

      # Apply pagination if specified
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
