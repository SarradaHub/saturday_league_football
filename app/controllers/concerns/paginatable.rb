# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  MAX_PER_PAGE = 100
  DEFAULT_PER_PAGE = 20

  included do
    def paginate_params
      {
        page: parse_page,
        per_page: parse_per_page
      }
    end

    def paginate_relation(relation)
      page = parse_page
      per_page = parse_per_page
      offset = (page - 1) * per_page

      relation.limit(per_page).offset(offset)
    end

    def pagination_meta(relation, page:, per_page:)
      total = relation.count
      total_pages = (total.to_f / per_page).ceil

      {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    end

    private

    def parse_page
      page = params[:page]&.to_i || 1
      page.positive? ? page : 1
    end

    def parse_per_page
      per_page = params[:per_page]&.to_i || DEFAULT_PER_PAGE
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      [per_page, MAX_PER_PAGE].min
    end
  end
end
