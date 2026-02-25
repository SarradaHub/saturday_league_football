# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < Api::BaseController
      include Paginatable
      include SparseFieldsets
      include Includable
      include Cacheable

      around_action :set_response_time_header

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

      protected

      def record_not_found
        render json: { error: 'Resource not found' }, status: :not_found
      end

      def render_collection(collection, serializer_class: nil, presenter_class: nil, base_relation: nil)
        if base_relation.nil?
          base_relation = if collection.is_a?(ActiveRecord::Relation)
                            collection.except(:limit, :offset)
          elsif collection.respond_to?(:first) && collection.first.is_a?(ActiveRecord::Base)
                            collection.first.class.all
          else
                            collection
          end
        end

        if base_relation.is_a?(ActiveRecord::Relation)
          base_relation_for_count = base_relation.except(:select)
          total = base_relation_for_count.count
        else
          total = base_relation.size
        end

        items = collection.is_a?(ActiveRecord::Relation) ? collection.to_a : collection

        includes_list = parse_includes
        serialized_items = if serializer_class
                             items.map { |item| serializer_class.new(item).as_json }
        elsif presenter_class
                             skip_nested = presenter_class == RoundPresenter && !includes_list.any?
                             items.map do |item|
                               presenter_class.new(item).as_json(
                                 include_players: includes_list.include?('players'),
                                 include_rounds: includes_list.include?('rounds'),
                                 skip_nested: skip_nested
                               )
                             end
        else
                             items.map(&:as_json)
        end

        allowed_fields = parse_fields
        serialized_items = filter_fields(serialized_items, allowed_fields) if allowed_fields.present?

        pagination = paginate_params
        total_pages = (total.to_f / pagination[:per_page]).ceil
        meta = {
          page: pagination[:page],
          per_page: pagination[:per_page],
          total: total,
          total_pages: total_pages
        }

        set_pagination_headers(pagination, total, total_pages)

        render json: {
          data: serialized_items,
          meta: meta
        }
      end

      def cacheable_resource?
        false
      end

      private

      def set_response_time_header
        start_time = Time.current
        yield
        response_time = ((Time.current - start_time) * 1000).round(2)
        response.headers['X-Response-Time'] = "#{response_time}ms"
      end

      def set_pagination_headers(pagination, total, total_pages)
        response.headers['X-Total-Count'] = total.to_s

        return unless total_pages.positive?

        current_page = pagination[:page]
        per_page = pagination[:per_page]

        base_params = request.query_parameters.merge(per_page: per_page)

        links = build_pagination_links(base_params, current_page, total_pages)
        response.headers['Link'] = links.join(', ') if links.any?
      end

      def build_pagination_links(base_params, current_page, total_pages)
        links = []

        if current_page < total_pages
          links << "<#{url_for(base_params.merge(page: current_page + 1))}>; rel=\"next\""
        end

        if current_page > 1 && current_page <= total_pages
          links << "<#{url_for(base_params.merge(page: current_page - 1))}>; rel=\"prev\""
        end

        links << "<#{url_for(base_params.merge(page: 1))}>; rel=\"first\""
        links << "<#{url_for(base_params.merge(page: total_pages))}>; rel=\"last\""
        links
      rescue ActionController::UrlGenerationError
        [] # controller specs with dynamic routes may not match url_for
      end
    end
  end
end
