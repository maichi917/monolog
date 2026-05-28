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

  test "finish_using finishes current usage log and redirects to used-up page" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    patch finish_using_item_path(item), params: {
      finished_at: "2026-05-12"
    }

    usage_log = item.usage_logs.finished.first
    assert_redirected_to edit_usage_log_path(usage_log)
    assert_equal Time.zone.local(2026, 5, 12), usage_log.finished_at
    assert_nil usage_log.rating
    assert_nil usage_log.review
  end

  test "finish_using_form shows date field" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get finish_using_form_item_path(item)

    assert_response :success
    assert_select "input[name='finished_at']"
  end

  test "finish_using_form redirects when item is not in use" do
    get finish_using_form_item_path(items(:one))

    assert_redirected_to in_use_items_path
  end

  test "in_use page has finish using form in item card" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get in_use_items_path

    assert_response :success
    assert_select "form[action='#{finish_using_item_path(item)}'] input[name='finished_at']"
    assert_select "button[data-disclosure-toggle]", text: "使い切る"
  end

  test "used_up page links to edit usage log" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4, review: "また使いたい")
    usage_log = item.usage_logs.finished.first

    get used_up_items_path

    assert_response :success
    assert_select "a[href='#{edit_usage_log_path(usage_log)}']", text: "編集"
  end

  test "destroy_image removes attached image and redirects to edit page" do
    item = items(:one)
    item.image.attach(
      io: StringIO.new("image"),
      filename: "item.png",
      content_type: "image/png"
    )

    assert item.image.attached?

    delete image_item_path(item)

    assert_redirected_to edit_item_path(item)
    assert_not item.reload.image.attached?
  end

  test "new page has submit loading message" do
    get new_item_path

    assert_response :success
    assert_select "[data-submit-loading]", text: "アイテムを登録しています..."
  end

  test "edit page has submit loading message" do
    get edit_item_path(items(:one))

    assert_response :success
    assert_select "[data-submit-loading]", text: "アイテム情報を更新しています..."
  end

  test "update with invalid image rerenders edit page" do
    item = items(:one)

    patch item_path(item), params: {
      item: {
        name: item.name,
        price: item.price,
        stock_quantity: item.stock_quantity,
        image: fixture_file_upload("test_file.txt", "text/plain")
      }
    }

    assert_response :unprocessable_content
    assert_includes response.body, "JPEGまたはPNG形式"
  end
end
