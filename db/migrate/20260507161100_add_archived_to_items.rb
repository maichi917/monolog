class AddArchivedToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :archived, :boolean, default: false, null: false
    add_index :items, :archived
  end
end
