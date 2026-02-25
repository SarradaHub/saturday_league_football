# frozen_string_literal: true

module Includable
  extend ActiveSupport::Concern

  included do
    def parse_includes
      return [] unless params[:include].present?

      params[:include].split(',').map(&:strip)
    end

    def apply_includes(relation, includes_list)
      return relation if includes_list.blank?

      # Convert string includes to symbols for ActiveRecord
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

      # Flatten nested includes for ActiveRecord
      # ActiveRecord accepts both :association and { association: {} }
      if includes_hash.any?
        relation.includes(includes_hash)
      else
        relation.includes(includes_list.map(&:to_sym))
      end
    end
  end
end
