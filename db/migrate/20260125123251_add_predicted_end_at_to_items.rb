class AddPredictedEndAtToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :predicted_end_at, :date
  end
end
