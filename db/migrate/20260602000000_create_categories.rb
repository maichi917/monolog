class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false

      t.timestamps
    end

    add_index :categories, [:user_id, :name], unique: true
  end
end
