# frozen_string_literal: true

class Match < ApplicationRecord
  include SoftDeletable

  belongs_to :round, counter_cache: :matches_count
  belongs_to :team_1, class_name: 'Team', foreign_key: 'team_1_id'
  belongs_to :team_2, class_name: 'Team', foreign_key: 'team_2_id'
  belongs_to :winning_team, class_name: 'Team', foreign_key: 'winning_team_id', optional: true
  has_many :player_stats, dependent: :destroy

  validates :name, presence: true

  before_destroy :handle_counter_cache_safely

  private

  def handle_counter_cache_safely
    # If round is being destroyed or already destroyed, handle counter cache manually
    if destroyed_by_association || round&.destroyed? || round&.marked_for_destruction?
      # Manually decrement counter cache using SQL to avoid ActiveRecord callbacks
      if round_id.present?
        begin
          # Use update_all to bypass ActiveRecord callbacks and validations
          Round.where(id: round_id).where('matches_count > 0').update_all('matches_count = matches_count - 1')
        rescue StandardError => e
          # Silently ignore errors (round may already be destroyed or in invalid state)
          Rails.logger.debug("Failed to update matches_count for round #{round_id}: #{e.message}")
        end
      end
      # Skip the automatic counter cache callback
      @_skip_counter_cache = true
    end
  end

  # Override Rails' counter cache callback to handle nil values
  def belongs_to_counter_cache_before_destroy_for_round
    return if @_skip_counter_cache
    return unless round_id.present?
    return if destroyed_by_association
    return if round&.destroyed? || round&.marked_for_destruction?
    
    begin
      # Call the original method if it exists
      super if defined?(super)
    rescue NoMethodError => e
      # Catch the -@ error and handle gracefully
      if e.message.include?("`-@' for nil")
        Rails.logger.debug("Counter cache update failed (round may be destroyed): #{e.message}")
      else
        raise
      end
    end
  end

end
