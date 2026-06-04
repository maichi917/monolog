require "test_helper"

class ItemTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile

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

  test "discontinue_using! discontinues current usage log" do
    item = items(:one)
    item.start_using!(users(:one), Time.zone.local(2026, 5, 10))

    item.discontinue_using!(Time.zone.local(2026, 5, 11), rating: 1, review: "肌に合わなかった")

    usage_log = item.usage_logs.finished.first
    assert_not item.using?
    assert_equal Time.zone.local(2026, 5, 11), usage_log.finished_at
    assert_equal "discontinued", usage_log.finish_reason
    assert_equal 1, usage_log.rating
    assert_equal "肌に合わなかった", usage_log.review
  end

  test "item can be saved without image" do
    item = items(:one)

    assert item.valid?
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
