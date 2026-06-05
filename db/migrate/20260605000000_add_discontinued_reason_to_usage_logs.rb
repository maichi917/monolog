class AddDiscontinuedReasonToUsageLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :usage_logs, :discontinued_reason, :text
  end
end
