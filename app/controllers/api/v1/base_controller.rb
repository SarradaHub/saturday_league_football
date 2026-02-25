# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include IdentityAuthentication
      include Paginatable
      include SparseFieldsets
      include Includable
      include Cacheable

      around_action :set_response_time_header

      # CSRF protection is not needed for API controllers
      # APIs typically use token-based authentication instead
      # respond_to is available via ActionController::MimeResponds included in ApplicationController

      protected

      def render_collection(collection, serializer_class: nil, presenter_class: nil, base_relation: nil)
        if base_relation.nil?
          base_relation = if collection.is_a?(ActiveRecord::Relation)
                            collection.except(:limit, :offset)
          else
                            collection.class.all
          end
        end

        total = base_relation.is_a?(ActiveRecord::Relation) ? base_relation.count : base_relation.size

        items = collection.is_a?(ActiveRecord::Relation) ? collection.to_a : collection

        serialized_items = if serializer_class
                             items.map { |item| serializer_class.new(item).as_json }
        elsif presenter_class
                             items.map { |item| presenter_class.new(item).as_json }
        else
                             items.map(&:as_json)
        end

        allowed_fields = parse_fields
        if allowed_fields.present?
          serialized_items = filter_fields(serialized_items, allowed_fields)
        end

        pagination = paginate_params
        total_pages = (total.to_f / pagination[:per_page]).ceil
        meta = {
          page: pagination[:page],
          per_page: pagination[:per_page],
          total: total,
          total_pages: total_pages
        }

        response.headers['X-Total-Count'] = total.to_s

        render json: {
          data: serialized_items,
          meta: meta
        }
      end

      private

      def requires_authentication?
        true
      end

      def set_response_time_header
        start_time = Time.current
        yield
        response_time = ((Time.current - start_time) * 1000).round(2)
        response.headers['X-Response-Time'] = "#{response_time}ms"
      end
    end
  end
end
