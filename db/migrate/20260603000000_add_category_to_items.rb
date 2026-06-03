class AddCategoryToItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :items, :category, foreign_key: true, type: :uuid
  end
end
