class ItemsController < ApplicationController
  before_action :authenticate_user! # ユーザーがログインしていることを確認

  def index
    @items = current_user.items.visible.order(created_at: :desc)

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
    @usage_logs = current_user.usage_logs
                              .finished
                              .includes(:item)
                              .order(finished_at: :desc)
  end

  def new
    @item = current_user.items.new # 新しいアイテムを作成
  end

  def create
    @item = current_user.items.build(item_params) # ログイン中のユーザーに紐づくアイテムを作成
    if @item.save
      redirect_to items_path, success: 'アイテムが作成されました。'
    else
    flash.now[:danger] = 'アイテムの作成に失敗しました。'  # ← flash.nowを使う！
    render :new, status: :unprocessable_entity
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

    if @item.update(item_params)
      redirect_to items_path, notice: 'アイテム情報を更新しました'
    else
      render :edit
    end
  end

  def destroy
    item = current_user.items.find(params[:id])
    item.destroy!
    redirect_to items_path, success: 'アイテムが削除されました'
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

  def finish_using
    @item = current_user.items.find(params[:id])
    usage_log = @item.current_usage_log

    if usage_log.blank?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
      return
    end

    @item.finish_using!(
      params[:finished_at],
      rating: params[:rating],
      review: params[:review]
    )

    redirect_to used_up_items_path, notice: "アイテムを使い切りました🎉"
  end

  private

  def set_item
    @item = current_user.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:name, :price, :stock_quantity, :favorite, :memo, :image)
  end
end
