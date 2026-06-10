class UsageLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_usage_log, only: %i[show edit update]
  before_action :set_discontinued_usage_log, only: %i[edit_discontinued_reason update_discontinued_reason]

  def show
  end

  def edit
  end

  def edit_discontinued_reason
  end

  def reviews
    @page_title = "評価・レビュー履歴"
    @search_query = params[:q].to_s.strip
    @usage_logs = current_user.usage_logs
                              .finished
                              .rated
                              .by_item_name(@search_query)
                              .includes(:item)
                              .order(finished_at: :desc)
                              .page(params[:page])
  end

  def update
    if @usage_log.update(usage_log_params)
      redirect_to used_up_items_path, notice: "評価とレビューを保存しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def update_discontinued_reason
    if @usage_log.update(discontinued_reason_params)
      redirect_to usage_log_path(@usage_log), notice: "使用中止理由を保存しました"
    else
      render :edit_discontinued_reason, status: :unprocessable_content
    end
  end

  private

  def set_usage_log
    @usage_log = current_user.usage_logs.finished.includes(:item).find(params[:id])
  end

  def set_discontinued_usage_log
    @usage_log = current_user.usage_logs.finished.discontinued.includes(:item).find(params[:id])
  end

  def usage_log_params
    params.require(:usage_log).permit(:rating, :review)
  end

  def discontinued_reason_params
    params.require(:usage_log).permit(:discontinued_reason)
  end
end
