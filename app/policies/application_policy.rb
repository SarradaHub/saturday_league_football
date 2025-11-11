# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user:, record:)
    @user = user
    @record = record
  end

  def allow?
    false
  end

  protected

  def permitted?
    allow?
  end
end
