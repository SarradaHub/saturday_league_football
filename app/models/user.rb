# frozen_string_literal: true

class User < ApplicationRecord
  include SoftDeletable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :championships, dependent: :destroy

  # Validations
  validates :external_id, uniqueness: true, allow_nil: true

  # Scopes
  scope :admin, -> { where(is_admin: true) }

  # Helper methods
  def admin?
    is_admin?
  end
end
