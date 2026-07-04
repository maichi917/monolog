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

  validates :started_at, presence: true
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
