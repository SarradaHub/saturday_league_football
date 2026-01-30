# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include IdentityAuthentication
      include Paginatable
      include SparseFieldsets
      include Includable

      # CSRF protection is not needed for API controllers
      # APIs typically use token-based authentication instead
      # respond_to is available via ActionController::MimeResponds included in ApplicationController

      protected

      def render_collection(collection, serializer_class: nil, presenter_class: nil, base_relation: nil)
        # Get base relation for count (before pagination)
        # If base_relation is provided, use it; otherwise try to get from collection
        if base_relation.nil?
          base_relation = if collection.is_a?(ActiveRecord::Relation)
                            # Remove limit and offset to get total count
                            collection.except(:limit, :offset)
          else
                            collection.class.all
          end
        end

        # Get total count before pagination
        total = base_relation.is_a?(ActiveRecord::Relation) ? base_relation.count : base_relation.size

        # Collection is already paginated by the query, just convert to array
        items = collection.is_a?(ActiveRecord::Relation) ? collection.to_a : collection

        # Serialize items
        serialized_items = if serializer_class
                             items.map { |item| serializer_class.new(item).as_json }
        elsif presenter_class
                             items.map { |item| presenter_class.new(item).as_json }
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

      private

      def requires_authentication?
        true
      end
    end
  end
end
