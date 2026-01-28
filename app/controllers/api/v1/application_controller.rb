# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < Api::BaseController
      include Paginatable
      include SparseFieldsets
      include Includable

      protected

      def render_collection(collection, serializer_class: nil, presenter_class: nil, base_relation: nil)
        # Get base relation for count (before pagination)
        # If base_relation is provided, use it; otherwise try to get from collection
        if base_relation.nil?
          base_relation = if collection.is_a?(ActiveRecord::Relation)
                            # Remove limit and offset to get total count
                            collection.except(:limit, :offset)
                          elsif collection.respond_to?(:first) && collection.first.is_a?(ActiveRecord::Base)
                            # If collection is an array of ActiveRecord objects, use the class
                            collection.first.class.all
                          else
                            # Fallback: use the collection itself for size
                            collection
                          end
        end

        # Get total count before pagination
        total = base_relation.is_a?(ActiveRecord::Relation) ? base_relation.count : base_relation.size

        # Collection is already paginated by the query, just convert to array
        items = collection.is_a?(ActiveRecord::Relation) ? collection.to_a : collection

        # Serialize items
        includes_list = parse_includes
        serialized_items = if serializer_class
                             items.map { |item| serializer_class.new(item).as_json }
                           elsif presenter_class
                             items.map { |item| presenter_class.new(item).as_json(include_players: includes_list.include?('players'), include_rounds: includes_list.include?('rounds')) }
                           else
                             items.map(&:as_json)
                           end

        # Apply sparse fieldsets
        allowed_fields = parse_fields
        if allowed_fields.present?
          serialized_items = filter_fields(serialized_items, allowed_fields)
        end

        # Get pagination meta
        pagination = paginate_params
        total_pages = (total.to_f / pagination[:per_page]).ceil
        meta = {
          page: pagination[:page],
          per_page: pagination[:per_page],
          total: total,
          total_pages: total_pages
        }

        render json: {
          data: serialized_items,
          meta: meta
        }
      end
    end
  end
end
