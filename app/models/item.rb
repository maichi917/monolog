class Item < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :price, numericality: { only_integer: true, allow_blank: true, greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  belongs_to :user
  has_many :usage_logs, dependent: :destroy

  # スコープ
  scope :visible, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  def current_usage_log
    usage_logs.in_use.order(started_at: :desc).first
  end

  def using?
    current_usage_log.present?
  end

  def stock_available?
    stock_quantity.to_i.positive?
  end

  def out_of_stock?
    stock_quantity.to_i.zero?
  end

  def start_using!(user, started_at)
    transaction do
      usage_logs.create!(
        user: user,
        started_at: started_at.presence || Time.current
      )

      decrement!(:stock_quantity)
    end
  end

  def finish_using!(finished_at, rating: nil, review: nil)
    current_usage_log.update!(
      finished_at: finished_at.presence || Time.current,
      rating: rating.presence,
      review: review.presence
    )
  end
end
