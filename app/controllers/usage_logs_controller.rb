class UsageLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_usage_log

  def edit
  end

  def update
    if @usage_log.update(usage_log_params)
      redirect_to used_up_items_path, notice: "評価とレビューを保存しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_usage_log
    @usage_log = current_user.usage_logs.finished.includes(:item).find(params[:id])
  end

  def usage_log_params
    params.require(:usage_log).permit(:rating, :review)
  end
end
