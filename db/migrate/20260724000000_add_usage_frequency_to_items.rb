class AddUsageFrequencyToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :usage_frequency, :string
  end
end
