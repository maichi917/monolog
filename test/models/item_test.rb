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
