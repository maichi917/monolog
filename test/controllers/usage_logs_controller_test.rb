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

  test "show displays usage log detail" do
    get usage_log_path(@usage_log)

    assert_response :success
    assert_includes response.body, @item.name
    assert_includes response.body, "使い始め日"
    assert_includes response.body, "終了日"
    assert_includes response.body, "使用期間"
    assert_select "a[href='#{item_path(@item)}']", text: "アイテム本体を見る"
  end

  test "reviews shows finished usage logs with rating and review" do
    @usage_log.update!(rating: 4, review: "また使いたい")

    get reviews_usage_logs_path

    assert_response :success
    assert_select "a.bg-emerald-600[href='#{reviews_usage_logs_path}']", text: "マイレビュー"
    assert_includes response.body, @item.name
    assert_select "dd", text: /★★★★\s*☆/
    assert_includes response.body, "また使いたい"
    assert_select "a[href='#{edit_usage_log_path(@usage_log)}']", text: "編集"
  end

  test "reviews shows rated usage log without review as no review" do
    @usage_log.update!(rating: 4, review: "")

    get reviews_usage_logs_path

    assert_response :success
    assert_includes response.body, @item.name
    assert_select "dd", text: /★★★★\s*☆/
    assert_includes response.body, "レビューなし"
  end

  test "reviews does not show unrated usage logs" do
    get reviews_usage_logs_path

    assert_response :success
    assert_no_match @item.name, response.body
  end

  test "reviews does not show other user's usage logs" do
    other_user = users(:two)
    other_item = other_user.items.create!(name: "他のアイテム", stock_quantity: 1)
    other_item.start_using!(other_user, Time.zone.local(2026, 5, 10))
    other_item.finish_using!(Time.zone.local(2026, 5, 12), rating: 5, review: "他ユーザー")

    get reviews_usage_logs_path

    assert_response :success
    assert_no_match "他のアイテム", response.body
    assert_no_match "他ユーザー", response.body
  end

  test "reviews searches rated usage logs by item name" do
    @usage_log.update!(rating: 4, review: "また使いたい")
    other_item = items(:two)
    other_item.update!(stock_quantity: 1)
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(
      Time.zone.local(2026, 5, 13),
      rating: 5,
      review: "しっとりした"
    )

    get reviews_usage_logs_path, params: { q: "化粧" }

    assert_response :success
    assert_includes response.body, @item.name
    assert_no_match other_item.name, response.body
    assert_select "input[name='q'][value='化粧']"
    assert_select "a[href='#{reviews_usage_logs_path}']", text: "リセット"
  end

  test "reviews shows a message when search has no results" do
    get reviews_usage_logs_path, params: { q: "存在しないアイテム" }

    assert_response :success
    assert_includes response.body, "条件に合う評価・レビュー履歴がありません"
    assert_select "a[href='#{reviews_usage_logs_path}']", text: "検索条件をリセット"
  end

  test "reviews filters usage logs by item category" do
    @item.update!(category: categories(:hair_care))
    @usage_log.update!(rating: 4)
    other_item = items(:two)
    other_item.update!(stock_quantity: 1, category: categories(:skin_care))
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(Time.zone.local(2026, 5, 13), rating: 5)

    get reviews_usage_logs_path, params: { category_id: categories(:hair_care).id }

    assert_response :success
    assert_includes response.body, @item.name
    assert_no_match other_item.name, response.body
    assert_select "a.bg-emerald-600", text: categories(:hair_care).name
  end

  test "reviews combines item name and category filters" do
    @item.update!(category: categories(:hair_care))
    @usage_log.update!(rating: 4)
    other_item = items(:two)
    other_item.update!(stock_quantity: 1, category: categories(:hair_care))
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(Time.zone.local(2026, 5, 13), rating: 5)

    get reviews_usage_logs_path, params: {
      q: "化粧",
      category_id: categories(:hair_care).id
    }

    assert_response :success
    assert_includes response.body, @item.name
    assert_no_match other_item.name, response.body
    assert_select "input[type='hidden'][name='category_id'][value='#{categories(:hair_care).id}']"
  end

  test "reviews filters usage logs for uncategorized items" do
    @item.update!(category: categories(:hair_care))
    @usage_log.update!(rating: 4)
    other_item = items(:two)
    other_item.update!(stock_quantity: 1)
    other_item.start_using!(@user, Time.zone.local(2026, 5, 11))
    other_item.finish_using!(Time.zone.local(2026, 5, 13), rating: 5)

    get reviews_usage_logs_path, params: { category_id: "uncategorized" }

    assert_response :success
    assert_includes response.body, other_item.name
    assert_no_match @item.name, response.body
    assert_select "a.bg-emerald-600", text: "未分類"
  end

  test "reviews keeps search and category filters in pagination links" do
    category = categories(:hair_care)
    11.times do |number|
      item = @user.items.create!(
        name: "検索対象#{number}",
        stock_quantity: 1,
        category: category
      )
      item.start_using!(@user, Time.zone.local(2026, 5, 10))
      item.finish_using!(Time.zone.local(2026, 5, 12), rating: 4)
    end

    get reviews_usage_logs_path, params: {
      q: "検索対象",
      category_id: category.id
    }

    assert_response :success
    assert_select "a[href='#{reviews_usage_logs_path(
      page: 2,
      q: "検索対象",
      category_id: category.id
    )}']"
  end

  test "header links to reviews page" do
    get reviews_usage_logs_path

    assert_response :success
    assert_select "a[href='#{reviews_usage_logs_path}']", text: "マイレビュー"
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

  test "other user's usage log cannot be shown" do
    other_user = users(:two)
    other_item = other_user.items.create!(name: "他のアイテム", stock_quantity: 1)
    other_item.start_using!(other_user, Time.zone.local(2026, 5, 10))
    other_item.finish_using!(Time.zone.local(2026, 5, 12))
    other_usage_log = other_item.usage_logs.finished.first

    get usage_log_path(other_usage_log)

    assert_response :not_found
  end

  test "edit_discontinued_reason shows reason form" do
    usage_log = create_discontinued_usage_log

    get edit_discontinued_reason_usage_log_path(usage_log)

    assert_response :success
    assert_select "textarea[name='usage_log[discontinued_reason]']"
    assert_select "a[href='#{usage_log_path(usage_log)}']", text: "戻る"
  end

  test "show has discontinued reason edit link" do
    usage_log = create_discontinued_usage_log

    get usage_log_path(usage_log)

    assert_response :success
    assert_select "a[href='#{edit_discontinued_reason_usage_log_path(usage_log)}']", text: "理由を編集"
  end

  test "update_discontinued_reason adds reason" do
    usage_log = create_discontinued_usage_log

    patch update_discontinued_reason_usage_log_path(usage_log), params: {
      usage_log: {
        discontinued_reason: "香りが苦手だった"
      }
    }

    assert_redirected_to usage_log_path(usage_log)
    assert_equal "香りが苦手だった", usage_log.reload.discontinued_reason
  end

  test "update_discontinued_reason changes reason" do
    usage_log = create_discontinued_usage_log(discontinued_reason: "肌に合わなかった")

    patch update_discontinued_reason_usage_log_path(usage_log), params: {
      usage_log: {
        discontinued_reason: "香りが苦手だった"
      }
    }

    assert_redirected_to usage_log_path(usage_log)
    assert_equal "香りが苦手だった", usage_log.reload.discontinued_reason
  end

  test "update_discontinued_reason clears reason" do
    usage_log = create_discontinued_usage_log(discontinued_reason: "肌に合わなかった")

    patch update_discontinued_reason_usage_log_path(usage_log), params: {
      usage_log: {
        discontinued_reason: ""
      }
    }

    assert_redirected_to usage_log_path(usage_log)
    assert_nil usage_log.reload.discontinued_reason
  end

  test "used up usage log cannot edit discontinued reason" do
    get edit_discontinued_reason_usage_log_path(@usage_log)

    assert_response :not_found
  end

  test "other user's usage log cannot edit discontinued reason" do
    other_user = users(:two)
    other_item = other_user.items.create!(name: "他のアイテム", stock_quantity: 1)
    other_item.start_using!(other_user, Time.zone.local(2026, 5, 10))
    other_item.discontinue_using!(Time.zone.local(2026, 5, 12))
    other_usage_log = other_item.usage_logs.finished.first

    get edit_discontinued_reason_usage_log_path(other_usage_log)

    assert_response :not_found
  end

  private

  def create_discontinued_usage_log(discontinued_reason: nil)
    item = items(:two)
    item.update!(stock_quantity: 1)
    item.start_using!(@user, Time.zone.local(2026, 5, 10))
    item.discontinue_using!(
      Time.zone.local(2026, 5, 12),
      discontinued_reason: discontinued_reason
    )
    item.usage_logs.finished.discontinued.first
  end
end
