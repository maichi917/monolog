class RemoveUsageStateFromItems < ActiveRecord::Migration[7.1]
  def change
    remove_index :items, :status
    remove_column :items, :status, :integer
    remove_column :items, :started_at, :date
    remove_column :items, :finished_at, :date
    remove_column :items, :predicted_end_at, :date
  end
end
