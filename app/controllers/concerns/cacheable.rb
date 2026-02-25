# frozen_string_literal: true

module Cacheable
  extend ActiveSupport::Concern

  included do
    before_action :set_cache_headers, if: -> { cacheable_request? }
    after_action :set_etag_header, if: -> { cacheable_request? }
  end

  private

  def cacheable_request?
    request.get? && cacheable_resource?
  end

  def cacheable_resource?
    false
  end

  def set_cache_headers
    expires_in 5.minutes, public: false if request.get?
  end

  def set_etag_header
    return unless request.get?

    etag = Digest::MD5.hexdigest(response.body.to_s)
    response.headers['ETag'] = %("#{etag}")

    if request.headers['If-None-Match'] == response.headers['ETag']
      head :not_modified
    end
  end
end
