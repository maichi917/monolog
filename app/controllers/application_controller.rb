class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  add_flash_types :success, :danger

  # ログイン後の遷移先を設定
  def after_sign_in_path_for(resource)
    items_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :email])
  end

  private

  def set_categories
    @categories = current_user.categories.order(:name)
  end

  # 一覧画面共通の検索・カテゴリ絞り込みパラメータを設定する
  def set_filter_params
    set_categories
    @search_query = params[:q].to_s.strip
    @selected_category_id = params[:category_id].to_s
  end
end
