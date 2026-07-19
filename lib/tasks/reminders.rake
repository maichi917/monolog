namespace :reminders do
  desc "購入リマインダーの対象アイテムを抽出して通知する（1日1回の定期実行を想定）"
  task deliver: :environment do
    count = PurchaseReminder.deliver_all
    puts "購入リマインダー: #{count}件のアイテムを通知しました"
  end
end
