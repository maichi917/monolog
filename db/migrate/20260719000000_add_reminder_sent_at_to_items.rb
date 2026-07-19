class AddReminderSentAtToItems < ActiveRecord::Migration[7.1]
  def change
    # 購入リマインダーの送信記録。1回目=予測日7日前、2回目=予測日3日前。
    # 予測日が変わったらリセットされる
    add_column :items, :reminder_first_sent_at, :datetime
    add_column :items, :reminder_second_sent_at, :datetime
  end
end
