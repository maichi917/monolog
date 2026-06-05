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

  test "discontinue_using discontinues current usage log and redirects to in-use page" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    patch discontinue_using_item_path(item), params: {
      finished_at: "2026-05-11",
      rating: 1,
      review: "肌に合わなかった"
    }

    usage_log = item.usage_logs.finished.first
    assert_redirected_to in_use_items_path
    assert_equal Time.zone.local(2026, 5, 11), usage_log.finished_at
    assert_equal "discontinued", usage_log.finish_reason
    assert_equal 1, usage_log.rating
    assert_equal "肌に合わなかった", usage_log.review
  end

  test "discontinue_using redirects when item is not in use" do
    item = items(:one)

    patch discontinue_using_item_path(item), params: {
      finished_at: "2026-05-11"
    }

    assert_redirected_to in_use_items_path
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

  test "discontinue_using_form shows date field" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get discontinue_using_form_item_path(item)

    assert_response :success
    assert_select "form[action='#{discontinue_using_item_path(item)}'] input[name='finished_at']"
    assert_select "input[type='submit'][value='使用を中止する']"
  end

  test "discontinue_using_form redirects when item is not in use" do
    get discontinue_using_form_item_path(items(:one))

    assert_redirected_to in_use_items_path
  end

  test "in_use page has finish using link in item card" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get in_use_items_path

    assert_response :success
    assert_select "a[href='#{finish_using_form_item_path(item)}']", text: "使い切る"
  end

  test "in_use page has discontinue using link in item card" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get in_use_items_path

    assert_response :success
    assert_select "a[href='#{discontinue_using_form_item_path(item)}']", text: "使用を中止する"
  end

  test "used_up page shows used up count" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4, review: "また使いたい")

    get used_up_items_path

    assert_response :success
    assert_includes response.body, "1回"
  end

  test "used_up page does not show discontinued usage logs" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.discontinue_using!(Time.zone.local(2026, 5, 12))

    get used_up_items_path

    assert_response :success
    assert_includes response.body, "使い切り履歴がありません"
    assert_no_match item.name, response.body
  end

  test "discontinued page shows discontinued usage logs" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.discontinue_using!(Time.zone.local(2026, 5, 12))

    get discontinued_items_path

    assert_response :success
    assert_includes response.body, item.name
    assert_includes response.body, "使用中止"
    assert_includes response.body, "使用期間"
  end

  test "used_up page shows one card per item with used up count" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4)
    item.update!(stock_quantity: 1)
    item.start_using!(@user, Time.zone.local(2026, 5, 20))
    item.finish_using!(Time.zone.local(2026, 5, 25), rating: 5)

    get used_up_items_path

    assert_response :success
    assert_select "article.ui-card", count: 1
    assert_includes response.body, "2回"
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

  test "new page has category select and new category field" do
    get new_item_path

    assert_response :success
    assert_select "select[name='item[category_id]']"
    assert_select "input[name='item[new_category_name]']"
    assert_includes response.body, categories(:hair_care).name
  end

  test "edit page has submit loading message" do
    get edit_item_path(items(:one))

    assert_response :success
    assert_select "[data-submit-loading]", text: "アイテム情報を更新しています..."
  end

  test "create assigns selected category to item" do
    category = categories(:hair_care)

    assert_difference -> { @user.items.count }, 1 do
      post items_path, params: {
        item: {
          name: "シャンプー",
          price: 1200,
          stock_quantity: 1,
          category_id: category.id
        }
      }
    end

    item = @user.items.order(:created_at).last
    assert_redirected_to items_path
    assert_equal category, item.category
  end

  test "create creates new category and assigns it to item" do
    assert_difference -> { @user.categories.count }, 1 do
      assert_difference -> { @user.items.count }, 1 do
        post items_path, params: {
          item: {
            name: "歯ブラシ",
            price: 300,
            stock_quantity: 2,
            new_category_name: "日用品"
          }
        }
      end
    end

    item = @user.items.order(:created_at).last
    assert_redirected_to items_path
    assert_equal "日用品", item.category.name
  end

  test "create rerenders new when new category is invalid" do
    assert_no_difference -> { @user.categories.count } do
      assert_no_difference -> { @user.items.count } do
        post items_path, params: {
          item: {
            name: "長いカテゴリのアイテム",
            price: 300,
            stock_quantity: 2,
            new_category_name: "あ" * 21
          }
        }
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, "新しいカテゴリ名は20文字以内で入力してください"
  end

  test "update changes category" do
    item = items(:one)
    category = categories(:skin_care)

    patch item_path(item), params: {
      item: {
        name: item.name,
        price: item.price,
        stock_quantity: item.stock_quantity,
        category_id: category.id
      }
    }

    assert_redirected_to items_path
    assert_equal category, item.reload.category
  end

  test "update creates new category and assigns it to item" do
    item = items(:one)

    assert_difference -> { @user.categories.count }, 1 do
      patch item_path(item), params: {
        item: {
          name: item.name,
          price: item.price,
          stock_quantity: item.stock_quantity,
          new_category_name: "メイク"
        }
      }
    end

    assert_redirected_to items_path
    assert_equal "メイク", item.reload.category.name
  end

  test "update removes category from item" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    patch item_path(item), params: {
      item: {
        name: item.name,
        price: item.price,
        stock_quantity: item.stock_quantity,
        remove_category: "1"
      }
    }

    assert_redirected_to items_path
    assert_nil item.reload.category
  end

  test "create cannot assign another user's category" do
    category = Category.create!(user: users(:two), name: "日用品")

    assert_no_difference -> { @user.items.count } do
      post items_path, params: {
        item: {
          name: "他ユーザーカテゴリのアイテム",
          price: 300,
          stock_quantity: 1,
          category_id: category.id
        }
      }
    end

    assert_response :not_found
  end

  test "index shows item category" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    get items_path

    assert_response :success
    assert_includes response.body, categories(:hair_care).name
  end

  test "show shows item category" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    get item_path(item)

    assert_response :success
    assert_includes response.body, categories(:hair_care).name
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
