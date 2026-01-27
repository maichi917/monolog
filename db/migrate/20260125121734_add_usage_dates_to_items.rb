class AddUsageDatesToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :started_at, :date
    add_column :items, :finished_at, :date
  end
end
