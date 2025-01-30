class AddDescriptionToChampionships < ActiveRecord::Migration[8.0]
  def change
    add_column :championships, :description, :string
  end
end
