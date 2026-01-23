# frozen_string_literal: true

module Teams
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Team.all, includes: [], page: nil, per_page: nil)
      @relation = relation
      @includes = includes
      @page = page
      @per_page = per_page
    end

    def call
      scope = relation.order(:name)

      # Apply includes only if specified
      if includes.any?
        scope = apply_includes(scope, includes)
      end

      # Apply pagination if specified
      if page && per_page
        offset = (page - 1) * per_page
        scope = scope.limit(per_page).offset(offset)
      end

      scope
    end

    private

    attr_reader :relation, :includes, :page, :per_page

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
