class Item < ApplicationRecord
  attr_accessor :new_category_name, :remove_category

  validates :name, presence: true, length: { maximum: 100 }
  validates :brand_name, length: { maximum: 100 }
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
  scope :by_name, ->(query) {
    return all if query.blank?

    where("name ILIKE ?", "%#{sanitize_sql_like(query)}%")
  }
  scope :by_category, ->(category_id) {
    return all if category_id.blank?
    return where(category_id: nil) if category_id == "uncategorized"

    where(category_id: category_id)
  }

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

  def average_usage_days
    durations = usage_logs
                .finished
                .used_up_history
                .where.not(started_at: nil)
                .map(&:usage_days)
                .select(&:positive?)

    return if durations.blank?

    (durations.sum.to_f / durations.size).round
  end

  def average_rating
    ratings = usage_logs.rated.pluck(:rating)
    return if ratings.blank?

    (ratings.sum.to_f / ratings.size).round(1)
  end

  def rating_count
    usage_logs.rated.count
  end

  def predicted_finish_date
    return unless using?
    return if current_usage_log.started_at.blank?

    average_days = average_usage_days
    return if average_days.blank?

    current_usage_log.started_at.to_date + (average_days - 1).days
  end

  # カテゴリを割り当てる。新規カテゴリ名があれば作成して設定し、
  # 作成に失敗した場合は errors に引き継いで false を返す
  def assign_category(user, category_id:, new_category_name:, remove_category:)
    self.new_category_name = new_category_name.to_s.strip
    self.remove_category = ActiveModel::Type::Boolean.new.cast(remove_category)

    if self.new_category_name.present?
      new_category = user.categories.find_or_initialize_by(name: self.new_category_name)
      unless new_category.save
        new_category.errors[:name].each { |message| errors.add(:new_category_name, message) }
        return false
      end

      self.category = new_category
    elsif self.remove_category
      self.category = nil
    elsif category_id.present?
      self.category = user.categories.find(category_id)
    else
      self.category = nil
    end

    true
  end

  def start_using!(user, started_at, started_at_unknown: false)
    transaction do
      usage_logs.create!(
        user: user,
        started_at: started_at_unknown ? nil : (started_at.presence || Time.current)
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

  def finish_and_continue_using!(user, usage_log, finished_at)
    with_lock do
      usage_log.reload
      unless usage_log.item_id == id && usage_log.in_use?
        errors.add(:base, "使用状態が更新されています")
        raise ActiveRecord::RecordInvalid, self
      end

      unless stock_available?
        errors.add(:stock_quantity, "がありません")
        raise ActiveRecord::RecordInvalid, self
      end

      continued_at = finished_at.presence || Time.current
      usage_log.update!(
        finished_at: continued_at,
        finish_reason: :used_up
      )
      start_using!(user, continued_at)
    end
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
