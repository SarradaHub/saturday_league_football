# frozen_string_literal: true

class AddUserIdToChampionships < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:championships, :user_id)
      add_reference :championships, :user, null: true, foreign_key: true
    end
  end

  def down
    if column_exists?(:championships, :user_id)
      remove_reference :championships, :user, foreign_key: true
    end
  end
end
