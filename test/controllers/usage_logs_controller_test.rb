require "test_helper"

class UsageLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user

    @item = items(:one)
    @item.start_using!(@user, Time.zone.local(2026, 5, 10))
    @item.finish_using!(Time.zone.local(2026, 5, 12))
    @usage_log = @item.usage_logs.finished.first
  end

  test "edit shows rating and review form" do
    get edit_usage_log_path(@usage_log)

    assert_response :success
    assert_select "select[name='usage_log[rating]']"
    assert_select "textarea[name='usage_log[review]']"
    assert_select "a[href='#{used_up_items_path}']", text: "レビューしない"
  end

  test "update saves rating and review" do
    patch usage_log_path(@usage_log), params: {
      usage_log: {
        rating: 5,
        review: "使いやすい"
      }
    }

    assert_redirected_to used_up_items_path
    assert_equal 5, @usage_log.reload.rating
    assert_equal "使いやすい", @usage_log.review
  end

  test "update rerenders edit when rating is invalid" do
    patch usage_log_path(@usage_log), params: {
      usage_log: {
        rating: 6,
        review: "評価が範囲外"
      }
    }

    assert_response :unprocessable_content
    assert_includes response.body, "入力内容を確認してください"
    assert_nil @usage_log.reload.rating
  end

  test "other user's usage log cannot be edited" do
    other_user = users(:two)
    other_item = other_user.items.create!(name: "他のアイテム", stock_quantity: 1)
    other_item.start_using!(other_user, Time.zone.local(2026, 5, 10))
    other_item.finish_using!(Time.zone.local(2026, 5, 12))
    other_usage_log = other_item.usage_logs.finished.first

    get edit_usage_log_path(other_usage_log)

    assert_response :not_found
  end
end
