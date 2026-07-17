require "test_helper"

class ItemTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  test "by_name returns items whose names partially match" do
    assert_equal [items(:one)], Item.by_name("化粧").to_a
  end

  test "by_name returns all items when query is blank" do
    assert_equal Item.order(:id).to_a, Item.by_name(" ").order(:id).to_a
  end

  test "by_category returns items in the selected category" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    assert_equal [item], Item.by_category(categories(:hair_care).id.to_s).to_a
  end

  test "by_category returns uncategorized items" do
    items(:one).update!(category: categories(:hair_care))

    assert_equal [items(:two)], Item.by_category("uncategorized").to_a
  end

  test "by_category returns all items when category is blank" do
    assert_equal Item.order(:id).to_a, Item.by_category("").order(:id).to_a
  end

  test "start_using! creates an in-use usage log and decreases stock" do
    item = items(:one)

    assert_difference -> { item.usage_logs.count }, 1 do
      item.start_using!(users(:one), Time.zone.local(2026, 5, 12))
    end

    assert_equal 1, item.reload.stock_quantity
    assert item.using?
    assert_equal users(:one), item.current_usage_log.user
  end

  test "assign_category creates and assigns a new category by name" do
    item = items(:one)
    user = users(:one)

    assert_difference -> { user.categories.count }, 1 do
      assert item.assign_category(user, category_id: nil, new_category_name: "日用品", remove_category: nil)
    end
    assert_equal "日用品", item.category.name
  end

  test "assign_category reuses an existing category with the same name" do
    item = items(:one)
    user = users(:one)
    existing = user.categories.create!(name: "日用品")

    assert_no_difference -> { user.categories.count } do
      assert item.assign_category(user, category_id: nil, new_category_name: "日用品", remove_category: nil)
    end
    assert_equal existing, item.category
  end

  test "assign_category returns false and adds error when new category name is invalid" do
    item = items(:one)
    user = users(:one)

    assert_not item.assign_category(user, category_id: nil, new_category_name: "あ" * 21, remove_category: nil)
    assert item.errors[:new_category_name].any?
  end

  test "assign_category removes category when remove_category is set" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    assert item.assign_category(users(:one), category_id: nil, new_category_name: nil, remove_category: "1")
    assert_nil item.category
  end

  test "assign_category assigns category by id scoped to the user" do
    item = items(:one)

    assert item.assign_category(users(:one), category_id: categories(:hair_care).id, new_category_name: nil, remove_category: nil)
    assert_equal categories(:hair_care), item.category
  end

  test "assign_category raises for another user's category id" do
    item = items(:one)
    other_category = users(:two).categories.create!(name: "他ユーザーカテゴリ")

    assert_raises(ActiveRecord::RecordNotFound) do
      item.assign_category(users(:one), category_id: other_category.id, new_category_name: nil, remove_category: nil)
    end
  end

  test "assign_category clears category when nothing is given" do
    item = items(:one)
    item.update!(category: categories(:hair_care))

    assert item.assign_category(users(:one), category_id: nil, new_category_name: nil, remove_category: nil)
    assert_nil item.category
  end

  test "start_using! with started_at_unknown creates usage log without started_at" do
    item = items(:one)

    item.start_using!(users(:one), Time.zone.local(2026, 5, 12), started_at_unknown: true)

    assert_nil item.current_usage_log.started_at
  end

  test "finish_using! finishes current usage log" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    item.finish_using!(Time.zone.local(2026, 5, 12), rating: 5, review: "使いやすい")

    usage_log = item.usage_logs.finished.first
    assert_not item.using?
    assert_equal Time.zone.local(2026, 5, 12), usage_log.finished_at
    assert_equal "used_up", usage_log.finish_reason
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

  test "finish_and_continue_using! finishes current log and starts next stock" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))
    continued_at = Time.zone.local(2026, 5, 12)

    assert_difference -> { item.usage_logs.count }, 1 do
      item.finish_and_continue_using!(users(:one), item.current_usage_log, continued_at)
    end

    finished_log = item.usage_logs.finished.first
    current_log = item.current_usage_log
    assert_equal 0, item.reload.stock_quantity
    assert_equal continued_at, finished_log.finished_at
    assert_equal "used_up", finished_log.finish_reason
    assert_equal continued_at, current_log.started_at
    assert_equal users(:one), current_log.user
  end

  test "finish_and_continue_using! rolls back when next usage log cannot be created" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    assert_no_difference -> { item.usage_logs.count } do
      assert_raises ActiveRecord::RecordInvalid do
        item.finish_and_continue_using!(nil, item.current_usage_log, Time.zone.local(2026, 5, 12))
      end
    end

    assert_equal 1, item.reload.stock_quantity
    assert item.using?
    assert_nil item.current_usage_log.finished_at
  end

  test "finish_and_continue_using! does not finish current log when stock is empty" do
    item = items(:one)
    item.update!(stock_quantity: 1)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    assert_no_difference -> { item.usage_logs.count } do
      assert_raises ActiveRecord::RecordInvalid do
        item.finish_and_continue_using!(users(:one), item.current_usage_log, Time.zone.local(2026, 5, 12))
      end
    end

    assert_equal 0, item.reload.stock_quantity
    assert item.using?
    assert_nil item.current_usage_log.finished_at
  end

  test "finish_and_continue_using! does not finish a usage log twice" do
    item = items(:one)
    item.update!(stock_quantity: 3)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))
    usage_log = item.current_usage_log
    item.finish_and_continue_using!(users(:one), usage_log, Time.zone.local(2026, 5, 12))

    assert_no_difference -> { item.usage_logs.count } do
      assert_raises ActiveRecord::RecordInvalid do
        item.finish_and_continue_using!(users(:one), usage_log, Time.zone.local(2026, 5, 12))
      end
    end

    assert_equal 1, item.reload.stock_quantity
    assert_equal 1, item.usage_logs.in_use.count
  end

  test "discontinue_using! discontinues current usage log" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    item.discontinue_using!(
      Time.zone.local(2026, 5, 11),
      discontinued_reason: "肌に合わなかった"
    )

    usage_log = item.usage_logs.finished.first
    assert_not item.using?
    assert_equal Time.zone.local(2026, 5, 11), usage_log.finished_at
    assert_equal "discontinued", usage_log.finish_reason
    assert_equal "肌に合わなかった", usage_log.discontinued_reason
    assert_nil usage_log.rating
    assert_nil usage_log.review
  end

  test "average_usage_days uses finished used-up usage logs" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))
    item.update!(stock_quantity: 1)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 20))
    item.finish_using!(Time.zone.local(2026, 5, 24))

    assert_equal 8, item.average_usage_days
  end

  test "average_usage_days ignores discontinued usage logs" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.discontinue_using!(Time.zone.local(2026, 5, 30))

    assert_nil item.average_usage_days
  end

  test "average_rating uses only usage logs with rating" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10), rating: 5)
    item.update!(stock_quantity: 1)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 20))
    item.finish_using!(Time.zone.local(2026, 5, 24), rating: 3)
    item.update!(stock_quantity: 1)
    item.start_using!(users(:one), Time.zone.local(2026, 6, 1))
    item.finish_using!(Time.zone.local(2026, 6, 5))

    assert_equal 4.0, item.average_rating
    assert_equal 2, item.rating_count
  end

  test "average_rating returns nil when item has no ratings" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))

    assert_nil item.average_rating
    assert_equal 0, item.rating_count
  end

  test "predicted_finish_date returns date from current usage start and average days" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))
    item.start_using!(users(:one), Time.zone.local(2026, 6, 1))

    assert_equal Date.new(2026, 6, 10), item.predicted_finish_date
  end

  test "predicted_finish_date returns nil when item is not in use" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))

    assert_nil item.predicted_finish_date
  end

  test "predicted_finish_date returns nil when used-up history is missing" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 6, 1))

    assert_nil item.predicted_finish_date
  end

  test "predicted_finish_date returns nil when current usage started_at is unknown" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 1))
    item.finish_using!(Time.zone.local(2026, 5, 10))
    item.start_using!(users(:one), Time.zone.local(2026, 6, 1), started_at_unknown: true)

    assert_nil item.predicted_finish_date
  end

  test "finish_predicted_soon? returns true when predicted date is within 7 days" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(users(:one), 10.days.ago)
    item.finish_using!(3.days.ago)
    item.start_using!(users(:one), Time.current)

    # 平均使用日数8日 → 予測日は7日後
    assert item.finish_predicted_soon?
  end

  test "finish_predicted_soon? returns true when predicted date has passed" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(users(:one), 30.days.ago)
    item.finish_using!(26.days.ago)
    item.start_using!(users(:one), 20.days.ago)

    # 平均使用日数5日 → 予測日は16日前（過ぎている）
    assert item.finish_predicted_soon?
  end

  test "finish_predicted_soon? returns false when predicted date is far" do
    item = items(:one)
    item.update!(stock_quantity: 2)
    item.start_using!(users(:one), 60.days.ago)
    item.finish_using!(1.day.ago)
    item.start_using!(users(:one), Time.current)

    # 平均使用日数60日 → 予測日は59日後
    assert_not item.finish_predicted_soon?
  end

  test "finish_predicted_soon? returns false without prediction" do
    item = items(:one)
    item.start_using!(users(:one), Time.current)

    # 使い切り履歴がなく予測日が計算できない
    assert_not item.finish_predicted_soon?
  end

  test "finish_predicted_soon returns matching items ordered by predicted date" do
    near_item = items(:one)
    near_item.update!(stock_quantity: 2)
    near_item.start_using!(users(:one), 10.days.ago)
    near_item.finish_using!(3.days.ago)
    near_item.start_using!(users(:one), Time.current)

    far_item = items(:two)
    far_item.update!(stock_quantity: 2)
    far_item.start_using!(users(:one), 60.days.ago)
    far_item.finish_using!(1.day.ago)
    far_item.start_using!(users(:one), Time.current)

    result = users(:one).items.finish_predicted_soon

    assert_includes result, near_item
    assert_not_includes result, far_item
  end

  test "item can be saved without image" do
    item = items(:one)

    assert item.valid?
  end

  test "item can be saved without brand name" do
    item = items(:one)
    item.brand_name = nil

    assert item.valid?
  end

  test "item rejects brand name over 100 characters" do
    item = items(:one)
    item.brand_name = "あ" * 101

    assert_not item.valid?
    assert_includes item.errors[:brand_name], "は100文字以内で入力してください"
  end

  test "item accepts png image" do
    item = items(:one)
    item.image.attach(
      fixture_file_upload("test_image.png", "image/png")
    )

    assert item.valid?
  end

  test "item image has display variants" do
    variants = Item.reflect_on_attachment(:image).named_variants

    assert_equal [160, 160], variants[:thumbnail].transformations[:resize_to_fill]
    assert_equal :webp, variants[:thumbnail].transformations[:format]
    assert_equal [512, 512], variants[:preview].transformations[:resize_to_fill]
    assert_equal :webp, variants[:preview].transformations[:format]
  end

  test "active storage uses vips for image processing" do
    assert_equal :vips, Rails.application.config.active_storage.variant_processor
  end

  test "item rejects non image file" do
    item = items(:one)
    item.image.attach(
      fixture_file_upload("test_file.txt", "text/plain")
    )

    assert_not item.valid?
    assert_includes item.errors[:image], "はJPEGまたはPNG形式でアップロードしてください"
  end

  test "item rejects image over 10 megabytes" do
    item = items(:one)
    item.image.attach(
      io: StringIO.new("a" * (10.megabytes + 1)),
      filename: "large.png",
      content_type: "image/png"
    )

    assert_not item.valid?
    assert_includes item.errors[:image], "は10MB以下にしてください"
  end

end
