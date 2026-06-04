class UsageLog < ApplicationRecord
  enum :finish_reason, {
    used_up: "used_up",
    discontinued: "discontinued"
  }, validate: { allow_nil: true }

  belongs_to :item
  belongs_to :user

  scope :in_use, -> { where(finished_at: nil) }
  scope :finished, -> { where.not(finished_at: nil) }
  scope :rated, -> { where.not(rating: nil) }

  validates :started_at, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true

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
