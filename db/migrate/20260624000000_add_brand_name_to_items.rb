class AddBrandNameToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :brand_name, :string
  end
end
