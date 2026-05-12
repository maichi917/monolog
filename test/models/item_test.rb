require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "start_using! creates an in-use usage log and decreases stock" do
    item = items(:one)

    assert_difference -> { item.usage_logs.count }, 1 do
      item.start_using!(users(:one), Time.zone.local(2026, 5, 12))
    end

    assert_equal 1, item.reload.stock_quantity
    assert item.using?
    assert_equal users(:one), item.current_usage_log.user
  end

  test "finish_using! finishes current usage log" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    item.finish_using!(Time.zone.local(2026, 5, 12), rating: 5, review: "使いやすい")

    usage_log = item.usage_logs.finished.first
    assert_not item.using?
    assert_equal Time.zone.local(2026, 5, 12), usage_log.finished_at
    assert_equal 5, usage_log.rating
    assert_equal "使いやすい", usage_log.review
  end

  test "finish_using! can finish without rating" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    item.finish_using!(Time.zone.local(2026, 5, 12), rating: "")

    usage_log = item.usage_logs.finished.first
    assert_not item.using?
    assert_nil usage_log.rating
  end

  test "finish_using! can finish without review" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    item.finish_using!(Time.zone.local(2026, 5, 12), review: "")

    usage_log = item.usage_logs.finished.first
    assert_not item.using?
    assert_nil usage_log.review
  end

end
