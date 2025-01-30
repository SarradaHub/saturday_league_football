# frozen_string_literal: true

class Round < ApplicationRecord
  belongs_to :championship
  has_many :matches, dependent: :destroy
  has_many :player_rounds
  accepts_nested_attributes_for :player_rounds, allow_destroy: true
  has_many :players, through: :player_rounds

  validates_presence_of :name
  validates_presence_of :round_date

  scope :for_championship, lambda { |championship_id|
    where(championship_id: championship_id)
      .order(round_date: :asc)
  }
end
