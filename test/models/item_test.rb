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

end
