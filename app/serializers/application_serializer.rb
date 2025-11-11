# frozen_string_literal: true

class ApplicationSerializer
  include ActiveModel::Serializers::JSON

  def initialize(resource)
    @resource = resource
  end

  private

  attr_reader :resource
end
