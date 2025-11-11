# frozen_string_literal: true

class ApplicationPresenter
  def initialize(resource)
    @resource = resource
  end

  private

  attr_reader :resource
end
