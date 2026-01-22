class ItemsController < ApplicationController
  before_action :authenticate_user! # ユーザーがログインしていることを確認

  def index
    @items = current_user.items.order(created_at: :desc) # ログイン中のユーザーのアイテムを取得
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

  private

  def item_params
    params.require(:item).permit(:name, :price, :stock_quantity, :status, :favorite, :memo, :image)
  end
end
