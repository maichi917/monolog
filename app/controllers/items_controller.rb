class ItemsController < ApplicationController
  before_action :authenticate_user! # ユーザーがログインしていることを確認

  def index
    @page_title = "アイテムリスト"
    @items = current_user.items.where(status: 'in_stock').order(created_at: :desc) # 在庫ありアイテムを取得
  end

  def in_use
    @page_title = "使用中アイテム"
    @items = current_user.items.where(status: 'in_use').order(created_at: :desc) # 使用中アイテムを取得
    render :index
  end

  def used_up
    @page_title = "使い切りアイテム"
    @items = current_user.items.where(status: 'used_up').order(created_at: :desc) # 使用済みアイテムを取得
    render :index
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
    @item = Item.find(params[:id])

    # ステータスが in_use に変更される場合、started_at を設定
    if item_params[:status] == 'in_use' && @item.in_stock?
      @item.started_at = item_params[:started_at] || Time.current
    end

    # ステータスが used_up に変更される場合、finished_at を設定
    if item_params[:status] == 'used_up' && @item.in_use?
      @item.finished_at = item_params[:finished_at] || Time.current
    end

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

  def restock
    @item = Item.find(params[:id])

    # 使い切り状態のアイテムを補充して在庫ありに戻す
    unless @item.used_up?
      redirect_to items_path, alert: 'このアイテムは補充できません'
      return
    end

    # ステータスをin_stockに戻し、在庫を`1`に設定
    @item.status = 'in_stock'
    @item.stock_quantity = 1

    # 使用開始日・終了日をクリア
    @item.started_at = nil
    @item.finished_at = nil

    if @item.save
      redirect_to items_path, success: '在庫を補充しました'
    else
      redirect_to used_up_items_path, alert: '在庫の補充に失敗しました'
    end
  end

  private

  def set_item
    @item = current_user.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:name, :price, :stock_quantity, :status, :favorite, :memo, :image, :started_at, :finished_at)
  end
end
