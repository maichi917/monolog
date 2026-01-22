class ItemsController < ApplicationController
  before_action :authenticate_user! # ユーザーがログインしていることを確認

  def index
    @items = current_user.items.order(created_at: :desc) # ログイン中のユーザーのアイテムを取得
  end
end
