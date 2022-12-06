class Shared::CategoriesFilterComponent < ApplicationComponent
  def initialize(categories:)
    @categories = categories
  end

  def link_path(order)
    if params[:current_tab_path].present?
      url_for(action: params[:current_tab_path], controller: 'pages', order: order, page: 1, anchor: anchor, filter_projekt_ids: params[:filter_projekt_ids])
    else
      current_path_with_query_params(order: order, anchor: anchor)
    end
  end
end
