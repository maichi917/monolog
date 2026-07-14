class ChangeUsageLogsStartedAtToOptional < ActiveRecord::Migration[7.1]
  def change
    change_column_null :usage_logs, :started_at, true
  end
end
