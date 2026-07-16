require "test_helper"

class UsageLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @item = items(:one)
  end

  test "by_item_name returns usage logs whose item names partially match" do
    matching_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10)
    )
    other_log = items(:two).usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 11)
    )

    assert_equal [matching_log], UsageLog.by_item_name("化粧").to_a
    assert_not_includes UsageLog.by_item_name("化粧"), other_log
  end

  test "by_item_name returns all usage logs when query is blank" do
    @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10)
    )

    assert_equal UsageLog.order(:id).to_a, UsageLog.by_item_name(" ").order(:id).to_a
  end

  test "by_item_category returns usage logs in the selected item category" do
    @item.update!(category: categories(:hair_care))
    matching_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10)
    )
    items(:two).update!(category: categories(:skin_care))
    items(:two).usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 11)
    )

    assert_equal [matching_log],
                 UsageLog.by_item_category(categories(:hair_care).id.to_s).to_a
  end

  test "by_item_category returns usage logs for uncategorized items" do
    @item.update!(category: categories(:hair_care))
    @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10)
    )
    uncategorized_log = items(:two).usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 11)
    )

    assert_equal [uncategorized_log],
                 UsageLog.by_item_category("uncategorized").to_a
  end

  test "by_item_category returns all usage logs when category is blank" do
    @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10)
    )

    assert_equal UsageLog.order(:id).to_a,
                 UsageLog.by_item_category("").order(:id).to_a
  end

  test "rated returns usage logs with rating" do
    rated_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 4
    )
    unrated_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 13),
      finished_at: Time.zone.local(2026, 5, 15)
    )

    assert_includes UsageLog.rated, rated_log
    assert_not_includes UsageLog.rated, unrated_log
  end

  test "by_rating_status filters rated usage logs" do
    rated_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 4
    )
    unrated_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 13),
      finished_at: Time.zone.local(2026, 5, 15)
    )

    assert_includes UsageLog.by_rating_status("rated"), rated_log
    assert_not_includes UsageLog.by_rating_status("rated"), unrated_log
  end

  test "by_rating_status filters unrated usage logs" do
    rated_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 4
    )
    unrated_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 13),
      finished_at: Time.zone.local(2026, 5, 15)
    )

    assert_includes UsageLog.by_rating_status("unrated"), unrated_log
    assert_not_includes UsageLog.by_rating_status("unrated"), rated_log
  end

  test "by_review_status filters reviewed usage logs" do
    reviewed_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 4,
      review: "また使いたい"
    )
    no_review_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 13),
      finished_at: Time.zone.local(2026, 5, 15),
      rating: 5
    )

    assert_includes UsageLog.by_review_status("reviewed"), reviewed_log
    assert_not_includes UsageLog.by_review_status("reviewed"), no_review_log
  end

  test "by_review_status filters usage logs without review" do
    reviewed_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 4,
      review: "また使いたい"
    )
    no_review_log = @item.usage_logs.create!(
      user: @user,
      started_at: Time.zone.local(2026, 5, 13),
      finished_at: Time.zone.local(2026, 5, 15),
      rating: 5
    )

    assert_includes UsageLog.by_review_status("unreviewed"), no_review_log
    assert_not_includes UsageLog.by_review_status("unreviewed"), reviewed_log
  end

  test "review requires rating" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      review: "使いやすい"
    )

    assert_not usage_log.valid?
    assert_includes usage_log.errors[:base], "レビューを入力する場合、星評価は必須です"
  end

  test "usage log is valid with rating and review" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 5,
      review: "使いやすい"
    )

    assert usage_log.valid?
  end

  test "usage log is valid with rating and without review" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      rating: 5
    )

    assert usage_log.valid?
  end

  test "usage log is valid without rating and review" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12)
    )

    assert usage_log.valid?
  end

  test "usage_days returns days including both start and finish dates" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 1),
      finished_at: Time.zone.local(2026, 5, 10)
    )

    assert_equal 10, usage_log.usage_days
  end

  test "usage_days returns nil when started_at is missing" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: nil,
      finished_at: Time.zone.local(2026, 5, 10)
    )

    assert_nil usage_log.usage_days
  end

  test "usage_days returns nil when finished_at is missing" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 1)
    )

    assert_nil usage_log.usage_days
  end

  test "days_in_use returns elapsed days including the start date" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: 2.days.ago
    )

    assert_equal 3, usage_log.days_in_use
  end

  test "days_in_use returns nil when started_at is missing" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: nil
    )

    assert_nil usage_log.days_in_use
  end

  test "usage log is valid without started_at" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: nil
    )

    assert usage_log.valid?
  end

  test "usage log accepts used up finish reason" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      finish_reason: :used_up
    )

    assert usage_log.valid?
    assert usage_log.used_up?
  end

  test "usage log accepts discontinued finish reason" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      finish_reason: :discontinued
    )

    assert usage_log.valid?
    assert usage_log.discontinued?
  end

  test "usage log accepts discontinued reason without rating" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      finish_reason: :discontinued,
      discontinued_reason: "肌に合わなかった"
    )

    assert usage_log.valid?
  end

  test "usage log rejects too long discontinued reason" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      finish_reason: :discontinued,
      discontinued_reason: "あ" * 501
    )

    assert_not usage_log.valid?
  end

  test "usage log rejects invalid finish reason" do
    usage_log = @item.usage_logs.build(
      user: @user,
      started_at: Time.zone.local(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 12),
      finish_reason: :unknown
    )

    assert_not usage_log.valid?
  end
end
