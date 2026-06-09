class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_categories, only: %i[index create]

  def index
    @category = current_user.categories.new
  end

  def create
    @category = current_user.categories.build(category_params)

    if @category.save
      redirect_to categories_path, success: "カテゴリを登録しました"
    else
      flash.now[:danger] = "カテゴリの登録に失敗しました"
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    category = current_user.categories.find(params[:id])
    category.destroy!
    redirect_to categories_path, success: "カテゴリを削除しました"
  end

  private

  def set_categories
    @categories = current_user.categories.order(:name).page(params[:page])
  end

  def category_params
    params.require(:category).permit(:name)
  end
end
