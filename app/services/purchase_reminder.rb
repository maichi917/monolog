# 購入リマインダーの対象アイテムを抽出し、ユーザーごとにまとめて通知する。
# 通知タイミングは2回: 予測日の7日前（1回目）と3日前（2回目）
class PurchaseReminder
  def self.deliver_all(notifier: ReminderNotifier.new)
    new(notifier: notifier).deliver_all
  end

  def initialize(notifier:)
    @notifier = notifier
  end

  # 通知したアイテム数を返す
  def deliver_all
    now = Time.current
    count = 0

    targets_by_user.each do |user, entries|
      @notifier.deliver(user, entries)
      entries.each do |entry|
        mark_sent(entry, now)
        count += 1
      end
    end

    count
  end

  private

  # 2回目（3日前）の対象を優先し、それ以外を1回目（7日前）の対象として集める。
  # 両方未送信のまま3日前を迎えた場合は、2回目としての1通だけを送る
  def targets_by_user
    second_due = Item.visible.reminder_second_due.includes(:user).to_a
    first_due = Item.visible.reminder_first_due
                    .where.not(id: second_due.map(&:id))
                    .includes(:user)
                    .to_a

    entries = second_due.map { |item| { item: item, stage: :second } } +
              first_due.map { |item| { item: item, stage: :first } }
    entries.group_by { |entry| entry[:item].user }
  end

  def mark_sent(entry, now)
    item = entry[:item]

    if entry[:stage] == :second
      item.update_columns(
        reminder_second_sent_at: now,
        reminder_first_sent_at: item.reminder_first_sent_at || now
      )
    else
      item.update_columns(reminder_first_sent_at: now)
    end
  end
end
