module ApplicationHelper
  def category_filter_class(selected_category_id, category_id)
    if selected_category_id.to_s == category_id.to_s
      "rounded-full bg-emerald-600 px-3 py-1.5 text-sm font-semibold text-white"
    else
      "rounded-full border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
    end
  end
end
