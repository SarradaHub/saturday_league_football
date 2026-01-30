# frozen_string_literal: true

class Round < ApplicationRecord
  include SoftDeletable

  belongs_to :championship, counter_cache: true
  has_many :matches, dependent: :destroy, counter_cache: true
  has_many :player_rounds, dependent: :destroy, counter_cache: :players_count
  accepts_nested_attributes_for :player_rounds, allow_destroy: true
  has_many :players, through: :player_rounds
  has_many :teams, dependent: :destroy

  validates_presence_of :name
  validates_presence_of :round_date

  scope :for_championship, lambda { |championship_id|
    where(championship_id: championship_id)
      .order(round_date: :asc)
  }
end
