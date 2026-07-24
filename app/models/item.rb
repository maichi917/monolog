class Item < ApplicationRecord
  attr_accessor :new_category_name, :remove_category

  # 使用頻度の選択肢。ユーザーには選択肢のまま見せ、厳密な回数入力は求めない
  USAGE_FREQUENCIES = %w[毎日 朝晩 週に数回 たまに その他].freeze

  # コスパ計算用の「週あたり想定使用回数」の目安（ユーザーには非表示）。
  # 選択式のまま計算に使えるようにするための内部マッピング。
  # 「その他」は回数を仮定できないため意図的に含めず、1日あたりコストにフォールバックする
  USAGE_FREQUENCY_WEEKLY_COUNTS = {
    "毎日" => 7,
    "朝晩" => 14,
    "週に数回" => 3,
    "たまに" => 1
  }.freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :brand_name, length: { maximum: 100 }
  validates :price, numericality: { only_integer: true, allow_blank: true, greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :usage_frequency, inclusion: { in: USAGE_FREQUENCIES }, allow_blank: true
  validate :image_content_type
  validate :image_size

  belongs_to :user
  belongs_to :category, optional: true
  has_many :usage_logs, dependent: :destroy
  has_one_attached :image do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [ 160, 160 ], format: :webp, saver: { quality: 80 }
    attachable.variant :preview, resize_to_fill: [ 512, 512 ], format: :webp, saver: { quality: 82 }
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

  # 1日あたりのコスト（価格 ÷ 平均使用日数）。価格または平均使用日数が無ければ nil
  def cost_per_day
    return if price.blank?

    average_days = average_usage_days
    return if average_days.blank?

    (price.to_f / average_days).round
  end

  # 1回あたりのコスト。使用頻度が「その他」・未設定、または平均使用日数が
  # 不明な場合は nil（呼び出し側は cost_per_day にフォールバックする）
  def cost_per_use
    return if price.blank?

    weekly_count = USAGE_FREQUENCY_WEEKLY_COUNTS[usage_frequency]
    return if weekly_count.blank?

    average_days = average_usage_days
    return if average_days.blank?

    expected_uses = average_days.to_f / 7 * weekly_count
    return if expected_uses.zero?

    (price.to_f / expected_uses).round
  end

  def average_rating
    ratings = usage_logs.rated.pluck(:rating)
    return if ratings.blank?

    (ratings.sum.to_f / ratings.size).round(1)
  end

  def rating_count
    usage_logs.rated.count
  end

  # 「もうすぐ無くなりそう」とみなす予測日までの日数
  FINISH_PREDICTED_SOON_DAYS = 7

  # 購入リマインダーの通知タイミング（予測日までの残り日数）
  REMINDER_FIRST_DAYS = 7
  REMINDER_SECOND_DAYS = 3

  # 1回目のリマインダー対象（予測日まで7日以内・未送信）
  scope :reminder_first_due, -> {
    where.not(predicted_finish_on: nil)
         .where(predicted_finish_on: ..(Date.current + REMINDER_FIRST_DAYS.days))
         .where(reminder_first_sent_at: nil)
  }
  # 2回目のリマインダー対象（予測日まで3日以内・未送信）
  scope :reminder_second_due, -> {
    where.not(predicted_finish_on: nil)
         .where(predicted_finish_on: ..(Date.current + REMINDER_SECOND_DAYS.days))
         .where(reminder_second_sent_at: nil)
  }

  # 使い切り予測日（キャッシュされたカラムを返す）
  def predicted_finish_date
    predicted_finish_on
  end

  # 使い切り予測日を再計算してカラムに保存する。使用履歴の変更時に呼ばれる。
  # 予測日が変わったら、新しいサイクルとしてリマインダーの送信記録もリセットする
  def refresh_predicted_finish_on!
    new_prediction = calculate_predicted_finish_on
    return if new_prediction == predicted_finish_on

    update_columns(
      predicted_finish_on: new_prediction,
      reminder_first_sent_at: nil,
      reminder_second_sent_at: nil
    )
  end

  # 使い切り予測日が近い（7日以内。予測日を過ぎている場合も含む）かどうか
  def finish_predicted_soon?
    predicted_finish_on.present? &&
      predicted_finish_on <= Date.current + FINISH_PREDICTED_SOON_DAYS.days
  end

  # 予測日が近いアイテムを予測日の早い順で返す
  def self.finish_predicted_soon
    where.not(predicted_finish_on: nil)
         .where(predicted_finish_on: ..(Date.current + FINISH_PREDICTED_SOON_DAYS.days))
         .order(:predicted_finish_on)
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

  # 使用履歴から使い切り予測日を計算する。予測できない場合は nil
  def calculate_predicted_finish_on
    return unless using?
    return if current_usage_log.started_at.blank?

    average_days = average_usage_days
    return if average_days.blank?

    current_usage_log.started_at.to_date + (average_days - 1).days
  end

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
