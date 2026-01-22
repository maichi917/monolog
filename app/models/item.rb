class Item < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :price, numericality: { only_integer: true, allow_blank: true, greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  belongs_to :user

    enum :status, {
    in_stock: 0,   # 在庫あり
    in_use: 1,     # 使用中
    used_up: 2     # 使い切り
  }, _prefix: true

  # スコープ：アイテムリスト用（在庫あり、使用中）
  scope :active_items, -> { where(status: [:in_stock, :in_use]) }

  # スコープ：使い切りアイテム用
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
end
