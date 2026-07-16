class ItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_categories, only: %i[new create edit update]
  before_action :set_item, only: %i[show edit update destroy destroy_image toggle_favorite
                                    start_using finish_using_form finish_using
                                    discontinue_using_form discontinue_using add_stock]

  def index
    @items = current_user.items.visible.includes(:category).order(created_at: :desc)
    @search_query = params[:q].to_s.strip
    @selected_category_id = params[:category_id].to_s
    @selected_status = params[:status].to_s
    @selected_favorite = params[:favorite].to_s
    @categories = current_user.categories.order(:name)
    @items = @items.by_name(@search_query)
                   .by_category(@selected_category_id)
    @items = @items.where(favorite: true) if @selected_favorite == "1"

    in_use_item_ids = current_user.usage_logs.in_use.select(:item_id)
    case @selected_status
    when "available"
      @items = @items.where("stock_quantity > 0").where.not(id: in_use_item_ids)
    when "in_use"
      @items = @items.where(id: in_use_item_ids)
    when "out_of_stock"
      @items = @items.where(stock_quantity: 0).where.not(id: in_use_item_ids)
    end

    @page_title = "アイテム"
    @items = @items.page(params[:page])
  end

  def in_use
    @page_title = "使用中アイテム"
    @search_query = params[:q].to_s.strip
    @selected_category_id = params[:category_id].to_s
    @categories = current_user.categories.order(:name)
    @usage_logs = current_user.usage_logs
                              .in_use
                              .by_item_name(@search_query)
                              .by_item_category(@selected_category_id)
                              .includes(:item)
                              .order(started_at: :desc)
                              .page(params[:page])
  end

  def used_up
    @page_title = "使い切り"
    @search_query = params[:q].to_s.strip
    @selected_category_id = params[:category_id].to_s
    @selected_rating = params[:rating].to_s
    @selected_rating_status = params[:rating_status].to_s
    @selected_review_status = params[:review_status].to_s
    @categories = current_user.categories.order(:name)
    finished_usage_logs = current_user.usage_logs
                                      .finished
                                      .used_up_history
                                      .by_item_name(@search_query)
                                      .by_item_category(@selected_category_id)
                                      .by_rating(@selected_rating)
                                      .by_rating_status(@selected_rating_status)
                                      .by_review_status(@selected_review_status)
                                      .includes(:item)
                                      .order(finished_at: :desc)
    @usage_logs = Kaminari.paginate_array(
      finished_usage_logs.to_a.uniq(&:item_id)
    ).page(params[:page])
    @used_up_counts_by_item_id = current_user.usage_logs
                                             .finished
                                             .used_up_history
                                             .group(:item_id)
                                             .count
  end

  def discontinued
    @page_title = "使用中止"
    @search_query = params[:q].to_s.strip
    @selected_category_id = params[:category_id].to_s
    @categories = current_user.categories.order(:name)
    @usage_logs = current_user.usage_logs
                              .finished
                              .discontinued
                              .by_item_name(@search_query)
                              .by_item_category(@selected_category_id)
                              .includes(:item)
                              .order(finished_at: :desc)
                              .page(params[:page])
  end

  def new
    @item = current_user.items.new
  end

  def create
    @item = current_user.items.build(item_params)

    if assign_category(@item) && @item.save
      redirect_to items_path, success: 'アイテムが作成されました。'
    else
      set_categories
      flash.now[:danger] = 'アイテムの作成に失敗しました。'
      render :new, status: :unprocessable_content
    end
  end

  def show
    @average_rating = @item.average_rating
    @rating_count = @item.rating_count
  end

  def edit
  end

  def update
    @item.assign_attributes(item_params)

    if assign_category(@item) && @item.save
      redirect_to items_path, notice: 'アイテム情報を更新しました'
    else
      set_categories
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @item.destroy!
    redirect_to items_path, success: 'アイテムが削除されました'
  end

  def destroy_image
    @item.image.purge
    redirect_to edit_item_path(@item), notice: "画像を削除しました"
  end

  def toggle_favorite
    @item.update!(favorite: !@item.favorite?)

    notice = @item.favorite? ? "お気に入りに追加しました" : "お気に入りを解除しました"
    redirect_back fallback_location: item_path(@item), notice: notice
  end

  def start_using
    if @item.using?
      redirect_to items_path, alert: "すでに使用中です"
      return
    end

    unless @item.stock_available?
      redirect_to items_path, alert: "在庫がありません"
      return
    end

    @item.start_using!(current_user, params[:started_at], started_at_unknown: params[:started_at_unknown].present?)
    redirect_to in_use_items_path, notice: "使用を開始しました"
  end

  def finish_using_form
    unless @item.using?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
    end
  end

  def finish_using
    usage_log =
      if params[:usage_log_id].present?
        @item.usage_logs.in_use.find_by(id: params[:usage_log_id])
      else
        @item.current_usage_log
      end

    if usage_log.blank?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
      return
    end

    continue_using = ActiveModel::Type::Boolean.new.cast(params[:continue_using])

    if continue_using
      begin
        @item.finish_and_continue_using!(current_user, usage_log, params[:finished_at])
      rescue ActiveRecord::RecordInvalid
        redirect_to in_use_items_path, alert: "在庫または使用状態が更新されたため、続けて使用を開始できませんでした"
        return
      end
    else
      @item.finish_using!(params[:finished_at])
    end

    notice =
      if continue_using
        "アイテムを使い切り、次の使用を開始しました"
      else
        "アイテムを使い切りました🎉"
      end

    redirect_to edit_usage_log_path(usage_log), notice: notice
  end

  def discontinue_using_form
    unless @item.using?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
    end
  end

  def discontinue_using
    usage_log = @item.current_usage_log

    if usage_log.blank?
      redirect_to in_use_items_path, alert: "使用中のアイテムがありません"
      return
    end

    @item.discontinue_using!(
      params[:finished_at],
      discontinued_reason: params[:discontinued_reason]
    )

    redirect_to in_use_items_path, notice: "使用を中止しました"
  end

  def add_stock
    quantity = params[:quantity].to_i

    if quantity.positive?
      @item.increment!(:stock_quantity, quantity)
      redirect_back fallback_location: items_path, notice: "在庫を追加しました"
    else
      redirect_back fallback_location: items_path, alert: "追加する個数を入力してください"
    end
  end

  private

  def set_item
    @item = current_user.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:name, :brand_name, :price, :stock_quantity, :favorite, :memo, :image)
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
