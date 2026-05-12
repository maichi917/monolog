class CreateItems < ActiveRecord::Migration[7.1]
  def change
    create_table :items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price
      t.integer :stock_quantity
      t.integer :status, default: 0, null: false # 0: in_stock, 1: in_use, 2: used_up
      t.boolean :favorite, default: false
      t.text :memo

      t.timestamps
    end

    add_index :items, :status
  end
end
