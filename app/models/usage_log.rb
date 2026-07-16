class UsageLog < ApplicationRecord
  normalizes :discontinued_reason, with: ->(reason) { reason.presence }

  enum :finish_reason, {
    used_up: "used_up",
    discontinued: "discontinued"
  }, validate: { allow_nil: true }

  belongs_to :item
  belongs_to :user

  scope :in_use, -> { where(finished_at: nil) }
  scope :finished, -> { where.not(finished_at: nil) }
  scope :used_up_history, -> { where(finish_reason: [finish_reasons[:used_up], nil]) }
  scope :rated, -> { where.not(rating: nil) }
  scope :by_rating, ->(rating) {
    return all if rating.blank?

    where(rating: rating)
  }
  scope :by_rating_status, ->(status) {
    case status
    when "rated"
      where.not(rating: nil)
    when "unrated"
      where(rating: nil)
    else
      all
    end
  }
  scope :by_review_status, ->(status) {
    case status
    when "reviewed"
      where.not(review: nil).where.not(review: "")
    when "unreviewed"
      where(review: [nil, ""])
    else
      all
    end
  }
  scope :by_item_name, ->(query) {
    return all if query.blank?

    joins(:item).where("items.name ILIKE ?", "%#{sanitize_sql_like(query)}%")
  }
  scope :by_item_category, ->(category_id) {
    return all if category_id.blank?
    return joins(:item).where(items: { category_id: nil }) if category_id == "uncategorized"

    joins(:item).where(items: { category_id: category_id })
  }
  # アイテムごとに finished_at が最も新しい1件だけに絞り込む（PostgreSQLのDISTINCT ONを利用）
  scope :latest_per_item, -> {
    where(id: reorder(item_id: :asc, finished_at: :desc)
                .select("DISTINCT ON (usage_logs.item_id) usage_logs.id"))
  }

  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validates :discontinued_reason, length: { maximum: 500 }, allow_blank: true

  validate :finished_at_must_be_after_started_at
  validate :review_requires_rating

  def in_use?
    finished_at.nil?
  end

  def finished?
    finished_at.present?
  end

  # 使用開始から終了までの日数（開始日・終了日を含む）。日付が欠けている場合は nil
  def usage_days
    return if started_at.blank? || finished_at.blank?

    (finished_at.to_date - started_at.to_date).to_i + 1
  end

  # 使用開始から今日までの経過日数（使用中の「◯日目」表示用）。開始日不明の場合は nil
  def days_in_use
    return if started_at.blank?

    (Date.current - started_at.to_date).to_i + 1
  end

  private

  def finished_at_must_be_after_started_at
    return if started_at.blank? || finished_at.blank?
    return if finished_at >= started_at

    errors.add(:finished_at, "は使用開始日時以降にしてください")
  end

  def review_requires_rating
    return if review.blank? || rating.present?

    errors.add(:base, "レビューを入力する場合、星評価は必須です")
  end
end
