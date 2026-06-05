require "test_helper"

class UsageLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @item = items(:one)
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
