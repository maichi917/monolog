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
    @item = current_user.items.find(params[:id])
    if @item.update(item_params)
      redirect_to items_path, success: 'アイテム情報が更新されました', item: Item.model_name.human
    else
      flash.now[:danger] = 'アイテム情報の更新に失敗しました'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    item = current_user.items.find(params[:id])
    item.destroy!
    redirect_to items_path, success: 'アイテムが削除されました'
  end

  private

  def item_params
    params.require(:item).permit(:name, :price, :stock_quantity, :status, :favorite, :memo, :image)
  end
end
