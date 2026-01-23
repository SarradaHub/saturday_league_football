# frozen_string_literal: true

module Players
  class CollectionQuery < ApplicationQuery
    def initialize(championship_id: nil, includes: [], page: nil, per_page: nil)
      @championship_id = championship_id
      @includes = includes
      @page = page
      @per_page = per_page
    end

    def call
      scope = Player.all
      scope = scope.in_championship(championship_id) if championship_id.present?

      # Apply includes only if specified
      if includes.any?
        scope = apply_includes(scope, includes)
      end

      scope = scope.order(:name)

      # Apply pagination if specified
      if page && per_page
        offset = (page - 1) * per_page
        scope = scope.limit(per_page).offset(offset)
      end

      scope
    end

    private

    attr_reader :championship_id, :includes, :page, :per_page

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
