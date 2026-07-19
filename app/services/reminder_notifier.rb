# 購入リマインダーの送信役。現在はログ出力のみ（#68 でLINE送信に差し替える予定）
class ReminderNotifier
  def deliver(user, entries)
    entries.each do |entry|
      item = entry[:item]
      Rails.logger.info(
        "[購入リマインダー] user=#{user.email} item=#{item.name} " \
        "予測日=#{item.predicted_finish_on} 在庫=#{item.stock_quantity} 通知=#{entry[:stage]}"
      )
    end
  end
end
