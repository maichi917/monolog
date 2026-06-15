module ApplicationHelper
  DEFAULT_META_TITLE = "ものログ".freeze
  DEFAULT_META_DESCRIPTION = "在庫とレビューを記録して、次の買い物でもう迷わない。日用品のストックと使用感をまとめて管理できるアプリです。".freeze
  DEFAULT_OG_IMAGE = "ogp.png".freeze

  def meta_title
    content_for?(:title) ? "#{content_for(:title)} | #{DEFAULT_META_TITLE}" : DEFAULT_META_TITLE
  end

  def meta_description
    content_for?(:description) ? content_for(:description) : DEFAULT_META_DESCRIPTION
  end

  def og_image_url
    image_url(content_for?(:og_image) ? content_for(:og_image) : DEFAULT_OG_IMAGE)
  end

  def category_filter_class(selected_category_id, category_id)
    if selected_category_id.to_s == category_id.to_s
      "rounded-full bg-emerald-600 px-3 py-1.5 text-sm font-semibold text-white"
    else
      "rounded-full border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
    end
  end
end
