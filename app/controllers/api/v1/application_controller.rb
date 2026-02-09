# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < Api::BaseController
      include Paginatable
      include SparseFieldsets
      include Includable

      protected

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

        total = base_relation.is_a?(ActiveRecord::Relation) ? base_relation.count : base_relation.size

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

        render json: {
          data: serialized_items,
          meta: meta
        }
      end
    end
  end
end
