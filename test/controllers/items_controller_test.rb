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
      finished_at: "2026-05-12",
      rating: 5,
      review: "使いやすい"
    }

    usage_log = item.usage_logs.finished.first
    assert_redirected_to used_up_items_path
    assert_equal 5, usage_log.rating
    assert_equal "使いやすい", usage_log.review
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
