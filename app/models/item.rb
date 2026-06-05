class Item < ApplicationRecord
  attr_accessor :new_category_name, :remove_category

  validates :name, presence: true, length: { maximum: 100 }
  validates :price, numericality: { only_integer: true, allow_blank: true, greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :image_content_type
  validate :image_size

  belongs_to :user
  belongs_to :category, optional: true
  has_many :usage_logs, dependent: :destroy
  has_one_attached :image do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [160, 160], format: :webp, saver: { quality: 80 }
    attachable.variant :preview, resize_to_fill: [512, 512], format: :webp, saver: { quality: 82 }
  end

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
      finish_reason: :used_up,
      rating: rating.presence,
      review: review.presence
    )
  end

  def discontinue_using!(finished_at, discontinued_reason: nil)
    current_usage_log.update!(
      finished_at: finished_at.presence || Time.current,
      finish_reason: :discontinued,
      discontinued_reason: discontinued_reason.presence
    )
  end

  private

  def image_content_type
    return unless image.attached?
    return if image.content_type.in?(%w[image/jpeg image/png])

    errors.add(:image, "はJPEGまたはPNG形式でアップロードしてください")
  end

  def image_size
    return unless image.attached?
    return if image.byte_size <= 10.megabytes

    errors.add(:image, "は10MB以下にしてください")
  end
end
