# frozen_string_literal: true

class User < ApplicationRecord
  include SoftDeletable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :championships, dependent: :destroy

  validates :external_id, uniqueness: true, allow_nil: true

  scope :admin, -> { where(is_admin: true) }

  def admin?
    is_admin?
  end
end
