require "test_helper"

class PurchaseReminderTest < ActiveSupport::TestCase
  # 通知内容を記録するだけのテスト用Notifier
  class FakeNotifier
    attr_reader :deliveries

    def initialize
      @deliveries = []
    end

    def deliver(user, entries)
      @deliveries << [user, entries]
    end
  end

  setup do
    @notifier = FakeNotifier.new
  end

  test "sends first reminder for items within 7 days and marks it sent" do
    item = items(:one)
    item.update!(predicted_finish_on: Date.current + 7.days)

    count = PurchaseReminder.deliver_all(notifier: @notifier)

    assert_equal 1, count
    user, entries = @notifier.deliveries.first
    assert_equal item.user, user
    assert_equal [{ item: item, stage: :first }], entries
    item.reload
    assert item.reminder_first_sent_at.present?
    assert_nil item.reminder_second_sent_at
  end

  test "sends a single second reminder when both stages are due" do
    item = items(:one)
    item.update!(predicted_finish_on: Date.current + 2.days)

    count = PurchaseReminder.deliver_all(notifier: @notifier)

    assert_equal 1, count
    _user, entries = @notifier.deliveries.first
    assert_equal :second, entries.first[:stage]
    item.reload
    assert item.reminder_first_sent_at.present?
    assert item.reminder_second_sent_at.present?
  end

  test "sends second reminder after first was already sent" do
    item = items(:one)
    first_sent_at = 4.days.ago
    item.update!(
      predicted_finish_on: Date.current + 3.days,
      reminder_first_sent_at: first_sent_at
    )

    count = PurchaseReminder.deliver_all(notifier: @notifier)

    assert_equal 1, count
    _user, entries = @notifier.deliveries.first
    assert_equal :second, entries.first[:stage]
    item.reload
    assert item.reminder_second_sent_at.present?
    assert_in_delta first_sent_at.to_i, item.reminder_first_sent_at.to_i, 1
  end

  test "does not notify items already sent" do
    item = items(:one)
    item.update!(
      predicted_finish_on: Date.current + 5.days,
      reminder_first_sent_at: Time.current
    )

    count = PurchaseReminder.deliver_all(notifier: @notifier)

    assert_equal 0, count
    assert_empty @notifier.deliveries
  end

  test "groups entries per user into one delivery" do
    items(:one).update!(predicted_finish_on: Date.current + 6.days)
    items(:two).update!(predicted_finish_on: Date.current + 2.days)

    count = PurchaseReminder.deliver_all(notifier: @notifier)

    assert_equal 2, count
    assert_equal 1, @notifier.deliveries.size
    _user, entries = @notifier.deliveries.first
    assert_equal 2, entries.size
  end

  test "excludes archived items" do
    item = items(:one)
    item.update!(predicted_finish_on: Date.current, archived: true)

    count = PurchaseReminder.deliver_all(notifier: @notifier)

    assert_equal 0, count
  end
end
