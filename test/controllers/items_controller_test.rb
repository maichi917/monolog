require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "index searches current user's items by partial name" do
    other_user_item = users(:two).items.create!(
      name: "化粧水 他ユーザー",
      stock_quantity: 1
    )

    get items_path, params: { q: "化粧" }

    assert_response :success
    assert_select "h2", text: items(:one).name
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
    assert_no_match other_user_item.name, response.body
  end

  test "index keeps search query and shows reset link" do
    get items_path, params: { q: "化粧" }

    assert_response :success
    assert_select "input[name='q'][value='化粧']"
    assert_select "a[href='#{items_path}']", text: "リセット"
  end

  test "header shows mobile and desktop navigation" do
    get items_path

    assert_response :success
    assert_select "img[src*='logo-mark'][alt='']"
    assert_select "details.md\\:hidden", count: 0
    assert_select "summary", text: /メニュー/, count: 0
    assert_select "nav[aria-label='スマートフォンメニュー'].md\\:hidden" do
      assert_select "a.bg-emerald-50[href='#{items_path}']", text: "アイテム"
      assert_select "a[href='#{items_path(status: "available")}']", text: "在庫あり", count: 0
      assert_select "a[href='#{in_use_items_path}']", text: "使用中", count: 0
      assert_select "a[href='#{used_up_items_path}']", text: "履歴"
      assert_select "a[href='#{guide_path}']", text: "使い方"
      assert_select "a[href='#{reviews_usage_logs_path}']", text: "レビュー", count: 0
      assert_select "details[data-menu-group='other']", count: 0
    end
    assert_select "nav[aria-label='メインメニュー'].md\\:flex" do
      assert_select "a.bg-emerald-50[href='#{items_path}']", text: "アイテム"
      assert_select "a[href='#{items_path(status: "available")}']", text: "在庫あり", count: 0
      assert_select "a[href='#{in_use_items_path}']", text: "使用中", count: 0
      assert_select "a[href='#{used_up_items_path}']", text: "履歴"
      assert_select "a[href='#{guide_path}']", text: "使い方"
      assert_select "a[href='#{reviews_usage_logs_path}']", text: "レビュー", count: 0
    end
  end

  test "index shows a message when search has no results" do
    get items_path, params: { q: "存在しないアイテム" }

    assert_response :success
    assert_includes response.body, "条件に合うアイテムがありません"
    assert_select "a[href='#{items_path}']", text: "検索条件をリセット"
  end

  test "index highlights out of stock item" do
    item = items(:two)

    get items_path

    assert_response :success
    assert_select "span.bg-red-50", text: "在庫なし"
    assert_select "span.font-bold.text-red-700", text: item.stock_quantity.to_s
  end

  test "index shows status filters" do
    get items_path

    assert_response :success
    assert_select "a[href='#{items_path}']", text: "すべて"
    assert_select "a[href='#{items_path(status: "available")}']", text: "在庫あり"
    assert_select "a[href='#{items_path(status: "in_use")}']", text: "使用中"
    assert_select "a[href='#{items_path(status: "out_of_stock")}']", text: "在庫なし"
  end

  test "index filters favorite items" do
    favorite_item = items(:one)
    favorite_item.update!(favorite: true)

    get items_path, params: { favorite: "1" }

    assert_response :success
    assert_includes response.body, favorite_item.name
    assert_no_match items(:two).name, response.body
    assert_select "a[href='#{items_path(favorite: "1")}']", text: /お気に入り/
    assert_select "form[action='#{toggle_favorite_item_path(favorite_item)}']"
  end

  test "toggle_favorite switches item favorite state" do
    item = items(:one)

    assert_changes -> { item.reload.favorite? }, from: false, to: true do
      patch toggle_favorite_item_path(item)
    end

    assert_redirected_to item_path(item)
  end

  test "index filters available items by status" do
    get items_path, params: { status: "available" }

    assert_response :success
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
  end

  test "index filters in-use items by status" do
    item = items(:one)
    item.start_using!(@user, Time.current)

    get items_path, params: { status: "in_use" }

    assert_response :success
    assert_includes response.body, item.name
    assert_no_match items(:two).name, response.body
  end

  test "index shows finish using modal for in-use item" do
    item = items(:one)
    item.start_using!(@user, Time.current)

    get items_path, params: { status: "in_use" }

    assert_response :success
    assert_select "button[data-disclosure-target='finish-using']", text: "使い切る"
    assert_select "form[action='#{finish_using_item_path(item)}'] input[name='finished_at']"
    assert_select "form[action='#{finish_using_item_path(item)}'] input[name='usage_log_id']"
  end

  test "index shows predicted finish date for in-use item with used-up history" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(@user, Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))
    item.start_using!(@user, Time.zone.local(2026, 6, 1))

    get items_path

    assert_response :success
    assert_includes response.body, "使い切り予測"
    assert_includes response.body, "6/10ごろ"
  end

  test "index shows unavailable prediction message for in-use item without used-up history" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 6, 1))

    get items_path

    assert_response :success
    assert_includes response.body, "使い切り予測"
    assert_includes response.body, "データなし"
  end

  test "index filters out-of-stock items by status" do
    get items_path, params: { status: "out_of_stock" }

    assert_response :success
    assert_includes response.body, items(:two).name
    assert_no_match items(:one).name, response.body
  end

  test "index shows add stock modal for every item" do
    item = items(:one)
    out_of_stock_item = items(:two)

    get items_path

    assert_response :success
    assert_select "button[data-disclosure-target='add-stock']", text: "在庫を追加"
    assert_select "form[action='#{add_stock_item_path(item)}'] input[name='quantity']"
    assert_select "form[action='#{add_stock_item_path(out_of_stock_item)}'] input[name='quantity']"
  end

  test "index links item information to detail page and hides detail button on mobile" do
    item = items(:one)

    get items_path

    assert_response :success
    assert_select "a[aria-label='#{item.name}の詳細を見る'][href='#{item_path(item)}']"
    assert_select "a.hidden[href='#{item_path(item)}']", text: "詳細"
  end

  test "index filters items by category" do
    items(:one).update!(category: categories(:hair_care))
    items(:two).update!(category: categories(:skin_care))

    get items_path, params: { category_id: categories(:hair_care).id }

    assert_response :success
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
  end

  test "index combines name and category filters" do
    items(:one).update!(category: categories(:hair_care))
    items(:two).update!(category: categories(:hair_care))

    get items_path, params: {
      q: "化粧",
      category_id: categories(:hair_care).id
    }

    assert_response :success
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
  end

  test "index filters uncategorized items" do
    items(:one).update!(category: categories(:hair_care))

    get items_path, params: { category_id: "uncategorized" }

    assert_response :success
    assert_includes response.body, items(:two).name
    assert_no_match items(:one).name, response.body
  end

  test "index does not show another user's items for another user's category" do
    other_user = users(:two)
    other_category = other_user.categories.create!(name: "他ユーザーカテゴリ")
    other_item = other_user.items.create!(
      name: "他ユーザーアイテム",
      stock_quantity: 1,
      category: other_category
    )

    get items_path, params: { category_id: other_category.id }

    assert_response :success
    assert_no_match other_item.name, response.body
  end

  test "index search form keeps selected category" do
    category = categories(:hair_care)

    get items_path, params: { category_id: category.id }

    assert_response :success
    assert_select "input[type='hidden'][name='category_id'][value='#{category.id}']"
  end

  test "index shows category links in filter drawer" do
    category = categories(:hair_care)

    get items_path

    assert_response :success
    assert_select "button[data-disclosure-target='filters']", text: /絞り込み/
    assert_select "div[data-disclosure-panel='filters']" do
      assert_select "h3", text: "Category"
      assert_select "a[href='#{items_path(category_id: category.id)}']", text: category.name
      assert_select "a[href='#{items_path(category_id: "uncategorized")}']", text: "未設定"
    end
  end

  test "index status filters keep selected category" do
    category = categories(:hair_care)

    get items_path, params: { category_id: category.id }

    assert_response :success
    assert_select "a[href='#{items_path(category_id: category.id, status: "available")}']", text: "在庫あり"
  end

  test "index does not show reset link when only category is selected" do
    get items_path, params: { category_id: categories(:hair_care).id }

    assert_response :success
    assert_select "a[href='#{items_path}']", text: "リセット", count: 0
  end

  test "index shows a message when category filter has no results" do
    empty_category = @user.categories.create!(name: "アイテムなし")

    get items_path, params: { category_id: empty_category.id }

    assert_response :success
    assert_includes response.body, "アイテムがありません"
    assert_select "a[href='#{items_path}']", text: "検索条件をリセット", count: 0
  end

  test "index keeps search category and status filters in pagination links" do
    category = categories(:hair_care)
    11.times do |number|
      @user.items.create!(
        name: "検索対象#{number}",
        stock_quantity: 1,
        category: category
      )
    end

    get items_path, params: {
      q: "検索対象",
      category_id: category.id,
      status: "available"
    }

    assert_response :success
    assert_select "a[href='#{items_path(
      page: 2,
      q: "検索対象",
      category_id: category.id,
      status: "available"
    )}']"
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

  test "add_stock increases stock quantity" do
    item = items(:two)

    assert_difference -> { item.reload.stock_quantity }, 3 do
      patch add_stock_item_path(item), params: { quantity: 3 }
    end

    assert_redirected_to items_path
    assert_equal "在庫を追加しました", flash[:notice]
  end

  test "add_stock does not change stock quantity when quantity is invalid" do
    item = items(:two)

    assert_no_difference -> { item.reload.stock_quantity } do
      patch add_stock_item_path(item), params: { quantity: 0 }
    end

    assert_redirected_to items_path
    assert_equal "追加する個数を入力してください", flash[:alert]
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

  test "finish_using starts next stock when continue_using is selected" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    usage_log = item.current_usage_log

    assert_difference -> { item.usage_logs.count }, 1 do
      patch finish_using_item_path(item), params: {
        finished_at: "2026-05-12",
        usage_log_id: usage_log.id,
        continue_using: "1"
      }
    end

    assert_redirected_to edit_usage_log_path(usage_log)
    assert_equal "アイテムを使い切り、次の使用を開始しました", flash[:notice]
    assert_equal 0, item.reload.stock_quantity
    assert_equal Time.zone.local(2026, 5, 12), usage_log.reload.finished_at
    assert_equal "used_up", usage_log.finish_reason
    assert_equal Time.zone.local(2026, 5, 12), item.current_usage_log.started_at
  end

  test "finish_using does not change usage log when continue_using is selected without stock" do
    item = items(:one)
    item.update!(stock_quantity: 1)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    usage_log = item.current_usage_log

    assert_no_difference -> { item.usage_logs.count } do
      patch finish_using_item_path(item), params: {
        finished_at: "2026-05-12",
        usage_log_id: usage_log.id,
        continue_using: "1"
      }
    end

    assert_redirected_to in_use_items_path
    assert_equal 0, item.reload.stock_quantity
    assert_nil usage_log.reload.finished_at
    assert item.using?
  end

  test "finish_using does not consume another stock when the same form is submitted twice" do
    item = items(:one)
    item.update!(stock_quantity: 3)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    usage_log = item.current_usage_log
    params = {
      finished_at: "2026-05-12",
      usage_log_id: usage_log.id,
      continue_using: "1"
    }

    patch finish_using_item_path(item), params: params

    assert_no_difference -> { item.usage_logs.count } do
      patch finish_using_item_path(item), params: params
    end

    assert_redirected_to in_use_items_path
    assert_equal 1, item.reload.stock_quantity
    assert_equal 1, item.usage_logs.in_use.count
  end

  test "discontinue_using discontinues current usage log and redirects to in-use page" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    patch discontinue_using_item_path(item), params: {
      finished_at: "2026-05-11",
      discontinued_reason: "肌に合わなかった"
    }

    usage_log = item.usage_logs.finished.first
    assert_redirected_to in_use_items_path
    assert_equal Time.zone.local(2026, 5, 11), usage_log.finished_at
    assert_equal "discontinued", usage_log.finish_reason
    assert_equal "肌に合わなかった", usage_log.discontinued_reason
    assert_nil usage_log.rating
    assert_nil usage_log.review
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
    assert_select "input[name='usage_log_id'][value='#{item.current_usage_log.id}']"
    assert_select "input[name='continue_using']"
    assert_select "span", text: "続けて新しく使う"
  end

  test "finish_using_form does not show continue option when stock is empty" do
    item = items(:one)
    item.update!(stock_quantity: 1)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get finish_using_form_item_path(item)

    assert_response :success
    assert_select "input[name='continue_using']", count: 0
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
    assert_select "textarea[name='discontinued_reason']"
    assert_select "input[type='submit'][value='使用を中止する']"
  end

  test "discontinue_using_form redirects when item is not in use" do
    get discontinue_using_form_item_path(items(:one))

    assert_redirected_to in_use_items_path
  end

  test "in_use page shows finish using modal in item card" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get in_use_items_path

    assert_response :success
    assert_select "dt", text: "在庫数"
    assert_select "button[data-disclosure-target='add-stock']", text: "在庫を追加"
    assert_select "form[action='#{add_stock_item_path(item)}'] input[name='quantity']"
    assert_includes response.body, "現在の在庫数"
    assert_select "button[data-disclosure-target='finish-using']", text: "使い切る"
    assert_select "form[action='#{finish_using_item_path(item)}'] input[name='finished_at']"
    assert_select "form[action='#{finish_using_item_path(item)}'] input[name='usage_log_id']"
    assert_select "button[data-disclosure-cancel]", text: "キャンセル"
  end

  test "in_use page shows discontinue using modal in item card" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get in_use_items_path

    assert_response :success
    assert_select "button[data-disclosure-target='discontinue-using']", text: "使用を中止する"
    assert_select "form[action='#{discontinue_using_item_path(item)}'] input[name='finished_at']"
    assert_select "form[action='#{discontinue_using_item_path(item)}'] textarea[name='discontinued_reason']"
    assert_select "button[data-disclosure-cancel]", text: "キャンセル"
  end

  test "in_use page searches current user's usage logs by item name" do
    matching_item = items(:one)
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    other_item = items(:two)
    other_item.update!(stock_quantity: 1)
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))

    get in_use_items_path, params: { q: "化粧" }

    assert_response :success
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
    assert_select "input[name='q'][value='化粧']"
    assert_select "a[href='#{in_use_items_path}']", text: "リセット"
  end

  test "in_use page shows a message when search has no results" do
    get in_use_items_path, params: { q: "存在しないアイテム" }

    assert_response :success
    assert_includes response.body, "条件に合う使用中アイテムがありません"
    assert_select "a[href='#{in_use_items_path}']", text: "検索条件をリセット"
  end

  test "in_use page filters usage logs by item category" do
    matching_item = items(:one)
    matching_item.update!(category: categories(:hair_care))
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    other_item = items(:two)
    other_item.update!(stock_quantity: 1, category: categories(:skin_care))
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))

    get in_use_items_path, params: { category_id: categories(:hair_care).id }

    assert_response :success
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
  end

  test "in_use page combines item name and category filters" do
    items(:one).update!(category: categories(:hair_care))
    items(:one).start_using!(@user, Time.zone.local(2026, 5, 10))
    items(:two).update!(stock_quantity: 1, category: categories(:hair_care))
    items(:two).start_using!(@user, Time.zone.local(2026, 5, 11))

    get in_use_items_path, params: {
      q: "化粧",
      category_id: categories(:hair_care).id
    }

    assert_response :success
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
    assert_select "input[type='hidden'][name='category_id'][value='#{categories(:hair_care).id}']"
  end

  test "in_use page filters usage logs for uncategorized items" do
    items(:one).update!(category: categories(:hair_care))
    items(:one).start_using!(@user, Time.zone.local(2026, 5, 10))
    items(:two).update!(stock_quantity: 1)
    items(:two).start_using!(@user, Time.zone.local(2026, 5, 11))

    get in_use_items_path, params: { category_id: "uncategorized" }

    assert_response :success
    assert_includes response.body, items(:two).name
    assert_no_match items(:one).name, response.body
  end

  test "in_use page shows category tags for current user only" do
    other_category = users(:two).categories.create!(name: "他ユーザーカテゴリ")

    get in_use_items_path

    assert_response :success
    assert_select "a", text: categories(:hair_care).name
    assert_select "a", text: "未分類"
    assert_select "a", text: other_category.name, count: 0
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
    assert_includes response.body, "理由は未入力です"
    assert_select "a[href='#{usage_log_path(item.usage_logs.finished.first)}']", text: "詳細"
  end

  test "discontinued page shows discontinued reason when present" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.discontinue_using!(
      Time.zone.local(2026, 5, 12),
      discontinued_reason: "香りが苦手だった"
    )

    get discontinued_items_path

    assert_response :success
    assert_includes response.body, "使用中止理由"
    assert_includes response.body, "香りが苦手だった"
  end

  test "discontinued page paginates usage logs with ten logs per page" do
    11.times do |number|
      item = @user.items.create!(
        name: "使用中止ページ確認#{number}",
        stock_quantity: 1
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.discontinue_using!(Time.zone.local(2026, 5, 12))
    end

    get discontinued_items_path

    assert_response :success
    assert_select "article", count: 10
    assert_select "a[href='#{discontinued_items_path(page: 2)}']"

    get discontinued_items_path(page: 2)

    assert_response :success
    assert_select "article", count: 1
  end

  test "discontinued page searches discontinued logs by item name" do
    matching_item = items(:one)
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    matching_item.discontinue_using!(Time.zone.local(2026, 5, 12))
    other_item = items(:two)
    other_item.update!(stock_quantity: 1)
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.discontinue_using!(Time.zone.local(2026, 5, 13))

    get discontinued_items_path, params: { q: "化粧" }

    assert_response :success
    assert_select "a.bg-emerald-600[href='#{discontinued_items_path}']", text: "使用中止"
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
    assert_select "input[name='q'][value='化粧']"
    assert_select "a[href='#{discontinued_items_path}']", text: "リセット"
  end

  test "discontinued page shows a message when search has no results" do
    get discontinued_items_path, params: { q: "存在しないアイテム" }

    assert_response :success
    assert_includes response.body, "条件に合う使用中止履歴がありません"
    assert_select "a[href='#{discontinued_items_path}']", text: "検索条件をリセット"
  end

  test "discontinued page keeps search query in pagination links" do
    11.times do |number|
      item = @user.items.create!(
        name: "検索対象#{number}",
        stock_quantity: 1
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.discontinue_using!(Time.zone.local(2026, 5, 12))
    end

    get discontinued_items_path, params: { q: "検索対象" }

    assert_response :success
    assert_select "a[href='#{discontinued_items_path(page: 2, q: "検索対象")}']"
  end

  test "discontinued page filters usage logs by item category" do
    matching_item = items(:one)
    matching_item.update!(category: categories(:hair_care))
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    matching_item.discontinue_using!(Time.zone.local(2026, 5, 12))
    other_item = items(:two)
    other_item.update!(stock_quantity: 1, category: categories(:skin_care))
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.discontinue_using!(Time.zone.local(2026, 5, 13))

    get discontinued_items_path, params: { category_id: categories(:hair_care).id }

    assert_response :success
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
    assert_select "a.bg-emerald-600[href='#{discontinued_items_path(category_id: categories(:hair_care).id)}']", text: categories(:hair_care).name
    assert_select "a[href='#{discontinued_items_path(category_id: "uncategorized")}']", text: "未設定"
  end

  test "discontinued page combines item name and category filters" do
    items(:one).update!(category: categories(:hair_care))
    items(:one).start_using!(@user, Time.zone.local(2026, 5, 10))
    items(:one).discontinue_using!(Time.zone.local(2026, 5, 12))
    items(:two).update!(stock_quantity: 1, category: categories(:hair_care))
    items(:two).start_using!(@user, Time.zone.local(2026, 5, 11))
    items(:two).discontinue_using!(Time.zone.local(2026, 5, 13))

    get discontinued_items_path, params: {
      q: "化粧",
      category_id: categories(:hair_care).id
    }

    assert_response :success
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
    assert_select "input[type='hidden'][name='category_id'][value='#{categories(:hair_care).id}']"
  end

  test "discontinued page filters usage logs for uncategorized items" do
    items(:one).update!(category: categories(:hair_care))
    items(:one).start_using!(@user, Time.zone.local(2026, 5, 10))
    items(:one).discontinue_using!(Time.zone.local(2026, 5, 12))
    items(:two).update!(stock_quantity: 1)
    items(:two).start_using!(@user, Time.zone.local(2026, 5, 11))
    items(:two).discontinue_using!(Time.zone.local(2026, 5, 13))

    get discontinued_items_path, params: { category_id: "uncategorized" }

    assert_response :success
    assert_includes response.body, items(:two).name
    assert_no_match items(:one).name, response.body
  end

  test "discontinued page keeps search and category filters in pagination links" do
    category = categories(:hair_care)
    11.times do |number|
      item = @user.items.create!(
        name: "検索対象#{number}",
        stock_quantity: 1,
        category: category
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.discontinue_using!(Time.zone.local(2026, 5, 12))
    end

    get discontinued_items_path, params: {
      q: "検索対象",
      category_id: category.id
    }

    assert_response :success
    assert_select "a[href='#{discontinued_items_path(
      page: 2,
      q: "検索対象",
      category_id: category.id
    )}']"
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
    assert_select "article", count: 1
    assert_includes response.body, "2回"
  end

  test "used_up page shows legacy finished logs without finish reason" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4)
    item.usage_logs.finished.first.update!(finish_reason: nil)

    get used_up_items_path

    assert_response :success
    assert_includes response.body, item.name
    assert_includes response.body, "1回"
  end

  test "used_up page searches used up logs by item name" do
    matching_item = items(:one)
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    matching_item.finish_using!(Time.zone.local(2026, 5, 12))
    other_item = items(:two)
    other_item.update!(stock_quantity: 1)
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(Time.zone.local(2026, 5, 13))

    get used_up_items_path, params: { q: "化粧" }

    assert_response :success
    assert_select "a.bg-emerald-600[href='#{used_up_items_path}']", text: "使い切り"
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
    assert_select "input[name='q'][value='化粧']"
    assert_select "a[href='#{used_up_items_path}']", text: "リセット"
  end

  test "used_up page shows a message when search has no results" do
    get used_up_items_path, params: { q: "存在しないアイテム" }

    assert_response :success
    assert_includes response.body, "条件に合う使い切り履歴がありません"
    assert_select "a[href='#{used_up_items_path}']", text: "検索条件をリセット"
  end

  test "used_up page keeps search query in pagination links" do
    11.times do |number|
      item = @user.items.create!(
        name: "検索対象#{number}",
        stock_quantity: 1
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.finish_using!(Time.zone.local(2026, 5, 12))
    end

    get used_up_items_path, params: { q: "検索対象" }

    assert_response :success
    assert_select "a[href='#{used_up_items_path(page: 2, q: "検索対象")}']"
  end

  test "used_up page filters usage logs by item category" do
    matching_item = items(:one)
    matching_item.update!(category: categories(:hair_care))
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    matching_item.finish_using!(Time.zone.local(2026, 5, 12))
    other_item = items(:two)
    other_item.update!(stock_quantity: 1, category: categories(:skin_care))
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(Time.zone.local(2026, 5, 13))

    get used_up_items_path, params: { category_id: categories(:hair_care).id }

    assert_response :success
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
    assert_select "a.bg-emerald-600[href='#{used_up_items_path(category_id: categories(:hair_care).id)}']", text: categories(:hair_care).name
    assert_select "a[href='#{used_up_items_path(category_id: "uncategorized")}']", text: "未設定"
  end

  test "used_up page combines item name and category filters" do
    items(:one).update!(category: categories(:hair_care))
    items(:one).start_using!(@user, Time.zone.local(2026, 5, 10))
    items(:one).finish_using!(Time.zone.local(2026, 5, 12))
    items(:two).update!(stock_quantity: 1, category: categories(:hair_care))
    items(:two).start_using!(@user, Time.zone.local(2026, 5, 11))
    items(:two).finish_using!(Time.zone.local(2026, 5, 13))

    get used_up_items_path, params: {
      q: "化粧",
      category_id: categories(:hair_care).id
    }

    assert_response :success
    assert_includes response.body, items(:one).name
    assert_no_match items(:two).name, response.body
    assert_select "input[type='hidden'][name='category_id'][value='#{categories(:hair_care).id}']"
  end

  test "used_up page filters usage logs for uncategorized items" do
    items(:one).update!(category: categories(:hair_care))
    items(:one).start_using!(@user, Time.zone.local(2026, 5, 10))
    items(:one).finish_using!(Time.zone.local(2026, 5, 12))
    items(:two).update!(stock_quantity: 1)
    items(:two).start_using!(@user, Time.zone.local(2026, 5, 11))
    items(:two).finish_using!(Time.zone.local(2026, 5, 13))

    get used_up_items_path, params: { category_id: "uncategorized" }

    assert_response :success
    assert_includes response.body, items(:two).name
    assert_no_match items(:one).name, response.body
  end

  test "used_up page filters usage logs by rating status" do
    rated_item = items(:one)
    rated_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    rated_item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4)
    unrated_item = items(:two)
    unrated_item.update!(stock_quantity: 1)
    unrated_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    unrated_item.finish_using!(Time.zone.local(2026, 5, 13))

    get used_up_items_path, params: { rating_status: "rated" }

    assert_response :success
    assert_includes response.body, rated_item.name
    assert_no_match unrated_item.name, response.body
    assert_select "a.bg-emerald-600[href='#{used_up_items_path(rating_status: "rated")}']", text: "評価あり"

    get used_up_items_path, params: { rating_status: "unrated" }

    assert_response :success
    assert_includes response.body, unrated_item.name
    assert_no_match rated_item.name, response.body
  end

  test "used_up page filters usage logs by rating" do
    matching_item = items(:one)
    matching_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    matching_item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4)
    other_item = items(:two)
    other_item.update!(stock_quantity: 1)
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(Time.zone.local(2026, 5, 13), rating: 5)

    get used_up_items_path, params: { rating: "4" }

    assert_response :success
    assert_includes response.body, matching_item.name
    assert_no_match other_item.name, response.body
    assert_select "a.bg-emerald-600[href='#{used_up_items_path(rating: 4)}']", text: /⭐️\s*4/
  end

  test "used_up page filters usage logs by review status" do
    reviewed_item = items(:one)
    reviewed_item.start_using!(@user, Time.zone.local(2026, 5, 10))
    reviewed_item.finish_using!(
      Time.zone.local(2026, 5, 12),
      rating: 4,
      review: "また使いたい"
    )
    no_review_item = items(:two)
    no_review_item.update!(stock_quantity: 1)
    no_review_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    no_review_item.finish_using!(Time.zone.local(2026, 5, 13), rating: 5)

    get used_up_items_path, params: { review_status: "reviewed" }

    assert_response :success
    assert_includes response.body, reviewed_item.name
    assert_no_match no_review_item.name, response.body
    assert_select "a.bg-emerald-600[href='#{used_up_items_path(review_status: "reviewed")}']", text: "レビューあり"

    get used_up_items_path, params: { review_status: "unreviewed" }

    assert_response :success
    assert_includes response.body, no_review_item.name
    assert_no_match reviewed_item.name, response.body
  end

  test "used_up page search form keeps selected rating and review filters" do
    get used_up_items_path, params: {
      rating: "4",
      rating_status: "rated",
      review_status: "reviewed"
    }

    assert_response :success
    assert_select "input[type='hidden'][name='rating'][value='4']"
    assert_select "input[type='hidden'][name='rating_status'][value='rated']"
    assert_select "input[type='hidden'][name='review_status'][value='reviewed']"
  end

  test "used_up page keeps search and category filters in pagination links" do
    category = categories(:hair_care)
    11.times do |number|
      item = @user.items.create!(
        name: "検索対象#{number}",
        stock_quantity: 1,
        category: category
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.finish_using!(Time.zone.local(2026, 5, 12))
    end

    get used_up_items_path, params: {
      q: "検索対象",
      category_id: category.id
    }

    assert_response :success
    assert_select "a[href='#{used_up_items_path(
      page: 2,
      q: "検索対象",
      category_id: category.id
    )}']"
  end

  test "used_up page keeps rating and review filters in pagination links" do
    11.times do |number|
      item = @user.items.create!(
        name: "レビュー検索対象#{number}",
        stock_quantity: 1
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.finish_using!(
        Time.zone.local(2026, 5, 12),
        rating: 4,
        review: "また使いたい"
      )
    end

    get used_up_items_path, params: {
      q: "レビュー検索対象",
      rating: "4",
      review_status: "reviewed"
    }

    assert_response :success
    assert_select "a[href='#{used_up_items_path(
      page: 2,
      q: "レビュー検索対象",
      rating: "4",
      review_status: "reviewed"
    )}']"
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

  test "new page image input supports camera capture" do
    get new_item_path

    assert_response :success
    assert_select "input#item_image_camera[type='file'][name='item[image]'][accept='image/jpeg,image/png'][capture='environment']"
    assert_select "label[for='item_image_camera'].md\\:hidden", text: "カメラを起動"
    assert_select "input#item_image_file[type='file'][name='item[image]'][accept='image/jpeg,image/png']"
    assert_select "label[for='item_image_file'].md\\:hidden", text: "フォルダからアップロード"
    assert_includes response.body, "撮影またはフォルダからアップロードできます"
    assert_includes response.body, "JPEG / PNG、10MB以下の画像を選択してください"
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

  test "edit page has stock quantity stepper" do
    item = items(:one)

    get edit_item_path(item)

    assert_response :success
    assert_select "label[for='item_stock_quantity']", text: "在庫数"
    assert_select "[data-stock-stepper]"
    assert_select "button[data-stock-stepper-action='decrement'][aria-label='在庫数を1減らす']", text: "-"
    assert_select "input[name='item[stock_quantity]'][min='0'][step='1'][value='#{item.stock_quantity}'][data-stock-stepper-input]"
    assert_select "button[data-stock-stepper-action='increment'][aria-label='在庫数を1増やす']", text: "+"
  end

  test "edit page image input supports camera capture" do
    get edit_item_path(items(:one))

    assert_response :success
    assert_select "input#item_image_camera[type='file'][name='item[image]'][accept='image/jpeg,image/png'][capture='environment']"
    assert_select "label[for='item_image_camera'].md\\:hidden", text: "カメラを起動"
    assert_select "input#item_image_file[type='file'][name='item[image]'][accept='image/jpeg,image/png']"
    assert_select "label[for='item_image_file'].md\\:hidden", text: "フォルダからアップロード"
    assert_includes response.body, "撮影またはフォルダからアップロードできます"
    assert_includes response.body, "JPEG / PNG、10MB以下の画像を選択してください"
  end

  test "new page has brand name field" do
    get new_item_path

    assert_response :success
    assert_select "label[for='item_brand_name']", "ブランド名"
    assert_select "input[name='item[brand_name]'][maxlength='100']"
  end

  test "edit page has brand name field" do
    get edit_item_path(items(:one))

    assert_response :success
    assert_select "label[for='item_brand_name']", "ブランド名"
    assert_select "input[name='item[brand_name]'][maxlength='100']"
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

  test "create saves brand name" do
    assert_difference -> { @user.items.count }, 1 do
      post items_path, params: {
        item: {
          name: "シャンプー",
          brand_name: "ものログ製薬",
          price: 1200,
          stock_quantity: 1
        }
      }
    end

    item = @user.items.order(:created_at).last
    assert_redirected_to items_path
    assert_equal "ものログ製薬", item.brand_name
  end

  test "create saves item without brand name" do
    assert_difference -> { @user.items.count }, 1 do
      post items_path, params: {
        item: {
          name: "無印アイテム",
          brand_name: "",
          price: 500,
          stock_quantity: 1
        }
      }
    end

    item = @user.items.order(:created_at).last
    assert_redirected_to items_path
    assert item.brand_name.blank?
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

  test "update changes brand name" do
    item = items(:one)

    patch item_path(item), params: {
      item: {
        name: item.name,
        brand_name: "ものログコスメ",
        price: item.price,
        stock_quantity: item.stock_quantity
      }
    }

    assert_redirected_to items_path
    assert_equal "ものログコスメ", item.reload.brand_name
  end

  test "update changes stock quantity" do
    item = items(:one)

    patch item_path(item), params: {
      item: {
        name: item.name,
        price: item.price,
        stock_quantity: 4
      }
    }

    assert_redirected_to items_path
    assert_equal 4, item.reload.stock_quantity
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

  test "index shows item brand name" do
    item = items(:one)
    item.update!(brand_name: "ものログ製薬")

    get items_path

    assert_response :success
    assert_includes response.body, "ものログ製薬"
  end

  test "index paginates items with ten items per page" do
    9.times do |number|
      @user.items.create!(
        name: "ページネーション確認#{number}",
        stock_quantity: 1
      )
    end

    get items_path

    assert_response :success
    assert_select "article", count: 10
    assert_select "a[href='#{items_path(page: 2)}']"

    get items_path(page: 2)

    assert_response :success
    assert_select "article", count: 1
  end

  test "show shows item category" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    get item_path(item)

    assert_response :success
    assert_includes response.body, categories(:hair_care).name
  end

  test "show shows item brand name" do
    item = items(:one)
    item.update!(brand_name: "ものログ製薬")

    get item_path(item)

    assert_response :success
    assert_includes response.body, "ブランド名"
    assert_includes response.body, "ものログ製薬"
  end

  test "show displays average rating and rating count" do
    item = items(:one)
    item.update!(stock_quantity: 3)
    item.start_using!(@user, Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10), rating: 5, review: "よかった")
    item.start_using!(@user, Time.zone.local(2026, 5, 20))
    item.finish_using!(Time.zone.local(2026, 5, 24), rating: 3)
    item.start_using!(@user, Time.zone.local(2026, 6, 1))
    item.finish_using!(Time.zone.local(2026, 6, 5))

    get item_path(item)

    assert_response :success
    assert_includes response.body, "平均評価"
    assert_includes response.body, "4.0"
    assert_includes response.body, "評価件数"
    assert_includes response.body, "2件"
  end

  test "show displays unrated message when item has no ratings" do
    item = items(:one)

    get item_path(item)

    assert_response :success
    assert_includes response.body, "平均評価"
    assert_includes response.body, "未評価"
    assert_includes response.body, "0件"
  end

  test "show uses consistent finish using button label for in-use item" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))

    get item_path(item)

    assert_response :success
    assert_select "button[data-disclosure-target='finish-using']", text: "使い切る"
    assert_select "button", text: "使い切り日を入力する", count: 0
  end

  test "show displays predicted finish date for in-use item with used-up history" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(@user, Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))
    item.start_using!(@user, Time.zone.local(2026, 6, 1))

    get item_path(item)

    assert_response :success
    assert_includes response.body, "使い切り予測"
    assert_includes response.body, "2026/6/10ごろ"
    assert_includes response.body, "平均10日"
  end

  test "show displays unavailable prediction message when history is missing" do
    item = items(:one)
    item.start_using!(@user, Time.zone.local(2026, 6, 1))

    get item_path(item)

    assert_response :success
    assert_includes response.body, "使い切り予測"
    assert_includes response.body, "使い切り履歴が足りないため、まだ予測できません。"
  end

  test "show highlights out of stock item and shows add stock modal" do
    item = items(:two)

    get item_path(item)

    assert_response :success
    assert_select "span.bg-red-50", text: "在庫なし"
    assert_select "dd.text-red-700", text: item.stock_quantity.to_s
    assert_select "button[data-disclosure-target='add-stock']", text: "在庫を追加"
    assert_select "form[action='#{add_stock_item_path(item)}'] input[name='quantity']"
  end

  test "show shows add stock modal for item with stock" do
    item = items(:one)

    get item_path(item)

    assert_response :success
    assert_select "button[data-disclosure-target='add-stock']", text: "在庫を追加"
    assert_select "form[action='#{add_stock_item_path(item)}'] input[name='quantity']"
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
