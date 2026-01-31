class Item < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :price, numericality: { only_integer: true, allow_blank: true, greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  belongs_to :user

  enum :status, {
    in_stock: 0,   # 在庫あり（未使用）
    in_use: 1,     # 使用中
    used_up: 2     # 使い切り
  }, _prefix: true

  # MVP1段階では在庫1のみ
  validates :stock_quantity, inclusion: { in: [1] }

  # ✅ ステータスと日付の整合性をバリデーション
  validates :started_at, presence: true, if: -> { in_use? || used_up? }
  validates :finished_at, presence: true, if: -> { used_up? }
  validate :dates_must_be_nil_when_in_stock

  # スコープ
  scope :in_stock_items, -> { where(status: :in_stock) }
  scope :in_use_items, -> { where(status: :in_use) }
  scope :used_up_items, -> { where(status: :used_up) }

  def status_i18n
    I18n.t("enums.item.status.#{status}")
  end

  # ステータスバッヂ
  def status_badge_color
    case status.to_sym
    when :in_stock
      'badge-success'   # 緑：在庫あり
    when :in_use
      'badge-warning'   # 黄：使用中
    when :used_up
      'badge-error'     # 赤：使い切り
    end
  end

  # 使用期間を計算（使い切った場合のみ、当日を含む）
  def usage_days
    return nil unless used_up? && started_at.present? && finished_at.present?
    (finished_at.to_date - started_at.to_date).to_i + 1
  end

  # 使い切るまでの期間を計算（日数）
  def total_usage_period
    return nil unless in_use? && started_at.present? && expected_end_at.present?
    (finished_at - started_at).to_i
  end

  # 🆕 1. 予測される使い切り日までの残り日数（使用中の場合）
  def days_until_predicted_end
    return nil unless in_use? && predicted_end_at
    (predicted_end_at - Date.today).to_i
  end

  # 使い切り予想日を表示（使い始める時に実行）
  def calculate_predicted_end_at!
    # 過去の使い切ったアイテムから平均使用期間を計算
    past_items = user.items
                     .where(status: :used_up)
                     .where.not(started_at: nil, finished_at: nil)

    # 過去データがない場合は予測しない
    return if past_items.empty?

    # 平均使用期間を計算
    total_days = past_items.sum { |item| (item.finished_at - item.started_at).to_i }
    average_days = total_days / past_items.size

    # 予測日を設定
    self.predicted_end_at = started_at + average_days.days
  end

  private

  # ✅ このメソッドを追加
  def dates_must_be_nil_when_in_stock
    return unless in_stock?  # 在庫ありステータスでない場合は何もしない

    if started_at.present?
      errors.add(:started_at, 'は在庫ありの場合は設定できません')
    end

    if finished_at.present?
      errors.add(:finished_at, 'は在庫ありの場合は設定できません')
    end
  end
end
