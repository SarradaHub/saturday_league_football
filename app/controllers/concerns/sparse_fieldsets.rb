# frozen_string_literal: true

module SparseFieldsets
  extend ActiveSupport::Concern

  included do
    def parse_fields
      return nil unless params[:fields].present?

      fields_value = params[:fields]
      # Handle both string and ActionController::Parameters
      fields_string = fields_value.is_a?(String) ? fields_value : fields_value.to_s
      fields_string.split(',').map(&:strip).map(&:to_sym)
    end

    def filter_fields(data, allowed_fields)
      return data unless allowed_fields.present?

      if data.is_a?(Array)
        data.map { |item| filter_fields(item, allowed_fields) }
      elsif data.is_a?(Hash)
        data.slice(*allowed_fields)
      else
        data
      end
    end
  end
end
