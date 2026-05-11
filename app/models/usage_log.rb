class UsageLog < ApplicationRecord
  belongs_to :item
  belongs_to :user

  scope :in_use, -> { where(finished_at: nil) }
  scope :finished, -> { where.not(finished_at: nil) }

  validates :started_at, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true

  validate :finished_at_must_be_after_started_at

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
end
