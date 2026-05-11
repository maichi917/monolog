class CreateUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :usage_logs do |t|
      t.references :item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :rating
      t.text :review

      t.timestamps
    end

    add_index :usage_logs, [:item_id, :finished_at]
    add_index :usage_logs, [:user_id, :finished_at]
    add_index :usage_logs, :item_id,
              unique: true,
              where: "finished_at IS NULL",
              name: "index_usage_logs_on_item_id_where_in_use"
  end
end
