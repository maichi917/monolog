class ItemsController < ApplicationController
  before_action :authenticate_user! # ユーザーがログインしていることを確認
  before_action :set_categories, only: %i[new create edit update]

  def index
    @items = current_user.items.visible.includes(:category).order(created_at: :desc)

    if params[:stock] == "available"
      @page_title = "ストックBOX"
      @items = @items.where("stock_quantity > 0")
    else
      @page_title = "アイテムDB"
    end
  end

  def in_use
    @page_title = "使用中アイテム"
    @usage_logs = current_user.usage_logs
                              .in_use
                              .includes(:item)
                              .order(started_at: :desc)
  end

  def used_up
    @page_title = "使い切り履歴"
    finished_usage_logs = current_user.usage_logs
                                      .finished
                                      .includes(:item)
                                      .order(finished_at: :desc)
    @usage_logs = finished_usage_logs.to_a.uniq(&:item_id)
    @used_up_counts_by_item_id = current_user.usage_logs
                                             .finished
                                             .group(:item_id)
                                             .count
  end

  def new
    @item = current_user.items.new # 新しいアイテムを作成
  end

  def create
    @item = current_user.items.build(item_params) # ログイン中のユーザーに紐づくアイテムを作成

    if assign_category(@item) && @item.save
      redirect_to items_path, success: 'アイテムが作成されました。'
    else
      set_categories
      flash.now[:danger] = 'アイテムの作成に失敗しました。'  # ← flash.nowを使う！
      render :new, status: :unprocessable_content
    end
  end

  def show
    @item = current_user.items.find(params[:id]) # ログイン中のユーザーのアイテムを取得
  end

  def edit
    @item = current_user.items.find(params[:id]) # ログイン中のユーザーのアイテムを取得
  end

  def update
    @item = current_user.items.find(params[:id])
    @item.assign_attributes(item_params)

    if assign_category(@item) && @item.save
      redirect_to items_path, notice: 'アイテム情報を更新しました'
    else
      set_categories
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    item = current_user.items.find(params[:id])
    item.destroy!
    redirect_to items_path, success: 'アイテムが削除されました'
  end

  def destroy_image
    item = current_user.items.find(params[:id])
    item.image.purge
    redirect_to edit_item_path(item), notice: "画像を削除しました"
  end

  def start_using
    @item = current_user.items.find(params[:id])

    if @item.using?
      redirect_to items_path, alert: "すでに使用中です"
      return
    end

    unless @item.stock_available?
      redirect_to items_path, alert: "在庫がありません"
      return
    end

    @item.start_using!(current_user, params[:started_at])
    redirect_to in_use_items_path, notice: "使用を開始しました"
  end

  def finish_using_form
    @item = current_user.items.find(params[:id])

    unless @item.using?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
    end
  end

  def finish_using
    @item = current_user.items.find(params[:id])
    usage_log = @item.current_usage_log

    if usage_log.blank?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
      return
    end

    @item.finish_using!(params[:finished_at])

    redirect_to edit_usage_log_path(usage_log), notice: "アイテムを使い切りました🎉"
  end

  private

  def set_item
    @item = current_user.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:name, :price, :stock_quantity, :favorite, :memo, :image)
  end

  def set_categories
    @categories = current_user.categories.order(:name)
  end

  def assign_category(item)
    category_name = params.dig(:item, :new_category_name).to_s.strip
    category_id = params.dig(:item, :category_id)
    remove_category = ActiveModel::Type::Boolean.new.cast(params.dig(:item, :remove_category))

    item.new_category_name = category_name
    item.remove_category = remove_category

    if category_name.present?
      category = current_user.categories.find_or_initialize_by(name: category_name)
      unless category.save
        category.errors[:name].each { |message| item.errors.add(:new_category_name, message) }
        return false
      end

      item.category = category
    elsif remove_category
      item.category = nil
    elsif category_id.present?
      item.category = current_user.categories.find(category_id)
    else
      item.category = nil
    end

    true
  end
end
