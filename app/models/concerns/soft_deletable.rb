# frozen_string_literal: true

module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Default scope to exclude soft-deleted records
    default_scope { where(is_deleted: false) }

    # Scope to get only deleted records
    scope :only_deleted, -> { unscope(where: :is_deleted).where(is_deleted: true) }

    # Scope to get all records including deleted ones
    scope :with_deleted, -> { unscope(where: :is_deleted) }

    # Callbacks for soft delete
    define_callbacks :soft_delete
    define_callbacks :restore
  end

  # Check if record is soft deleted
  def deleted?
    is_deleted?
  end

  # Soft delete the record
  def soft_delete
    return false if deleted?

    # Use update_column to bypass validations and callbacks
    # This is intentional for soft delete - we just mark as deleted
    update_column(:is_deleted, true) if has_attribute?(:is_deleted)
    true
  end

  # Restore a soft-deleted record
  def restore
    return false unless deleted?

    # Use update_column to bypass validations and callbacks
    # This is intentional for restore - we just unmark as deleted
    update_column(:is_deleted, false) if has_attribute?(:is_deleted)
    true
  end

  # Override destroy to perform soft delete by default
  def destroy
    return false if deleted?

    transaction do
      result = run_callbacks(:destroy) do
        soft_delete
      end
      result ? self : false
    end
  end

  # Hard delete - permanently remove from database with cascade
  def hard_delete
    transaction do
      # Delete dependent associations recursively
      delete_dependent_associations

      # Run callbacks before final deletion
      # This allows validations and cleanup logic to run
      catch(:abort) do
        run_callbacks(:destroy) do
          # Use delete to bypass soft delete and remove from database
          delete
        end
        return true
      end
      # If callback aborted, rollback transaction
      raise ActiveRecord::RecordNotDestroyed
    end
  end

  private

  # Delete all dependent associations configured with dependent: :destroy
  def delete_dependent_associations
    self.class.reflect_on_all_associations(:has_many).each do |association|
      next unless association.options[:dependent] == :destroy

      association_name = association.name
      next unless respond_to?(association_name)

      # Get dependent records - use with_deleted if association model has SoftDeletable
      dependent_class = association.klass
      base_relation = send(association_name)

      # If dependent model has SoftDeletable, include soft-deleted records in cascade
      if dependent_class.included_modules.include?(SoftDeletable)
        dependent_records = base_relation.with_deleted
      else
        dependent_records = base_relation
      end

      next if dependent_records.empty?

      if dependent_class.included_modules.include?(SoftDeletable)
        # For soft-deletable models, use hard_delete recursively
        # This ensures cascade continues through the hierarchy
        dependent_records.find_each do |record|
          # Skip if already hard deleted (safety check)
          next if record.destroyed?

          record.hard_delete
        end
      else
        # For non-soft-deletable models, check if callbacks are needed
        if has_important_callbacks?(dependent_class)
          # Use destroy_all to trigger callbacks (slower but safer)
          # Since model doesn't have SoftDeletable, destroy_all will work normally
          dependent_records.destroy_all
        else
          # Use delete_all for performance when callbacks aren't critical
          dependent_records.delete_all
        end
      end
    end
  end

  # Check if the model has important callbacks that should be executed
  def has_important_callbacks?(klass)
    # Check for before_destroy callbacks that might have validations or cleanup
    callbacks = klass._destroy_callbacks.select { |cb| cb.kind == :before }
    callbacks.any? { |cb| cb.filter.is_a?(Symbol) || cb.filter.is_a?(Proc) }
  end

  # Class method to restore by ID
  def self.restore(id)
    record = unscoped.find_by(id: id)
    return false unless record&.deleted?

    record.restore
  end
end
