class AddFinishReasonToUsageLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :usage_logs, :finish_reason, :string
    add_index :usage_logs, :finish_reason
  end
end
