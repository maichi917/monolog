require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "start_using creates usage log and redirects to in-use page" do
    item = items(:one)

    assert_difference -> { item.usage_logs.count }, 1 do
      patch start_using_item_path(item), params: { started_at: "2026-05-12" }
    end

    assert_redirected_to in_use_items_path
    assert_equal 1, item.reload.stock_quantity
  end

  test "start_using does not create usage log when stock is empty" do
    item = items(:two)

    assert_no_difference -> { item.usage_logs.count } do
      patch start_using_item_path(item), params: { started_at: "2026-05-12" }
    end

    assert_redirected_to items_path
    assert_equal 0, item.reload.stock_quantity
  end

  test "start_using does not create usage log when item is already in use" do
    item = items(:one)
    item.start_using!(@user, Time.current)

    assert_no_difference -> { item.usage_logs.count } do
      patch start_using_item_path(item), params: { started_at: "2026-05-12" }
    end

    assert_redirected_to items_path
    assert_equal 1, item.reload.stock_quantity
  end
end
