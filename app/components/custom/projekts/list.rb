class Projekts::List < ApplicationComponent
  def initialize(
    projekts:, title: nil,
    all_projekts: nil, map_coordinates: nil,
    content_only: false, filters: nil,
    current_filter: nil, only_content: false, overview_page_mode: false, anchor: nil,
    load_resources_url: nil,
    hide_title: false, no_filter: false,
    full_page_reload: false
  )
    @projekts = projekts
    @map_coordinates = map_coordinates
    @current_filter = current_filter
    @filters = filters
    @only_content = only_content
    @anchor = anchor
    @title = title.presence || t("custom.projekts.projekt_list.title")
    @hide_title = hide_title
    @no_filter = no_filter
    @load_resources_url = load_resources_url
    @full_page_reload = full_page_reload
  end

  def call
    render(Shared::ResourcesList.new(
      resources: @projekts,
      title: @title,
      map_coordinates: @map_coordinates,
      wide: false,
      load_resources_url: @load_resources_url,
      current_filter: @current_filter,
      filter_i18n_scope: "custom.projekts.orders",
      filter_param: "order",
      filters: @filters,
      only_content: @only_content,
      css_class: "js-projekts-list",
      hide_title: @hide_title,
      filter_title: t("custom.projekts.filter.title"),
      no_filter: @no_filter,
      no_items_text: t("custom.projekts.index.no_projekts_for_current_filter"),
      full_page_reload: @full_page_reload
    ))
  end
  #
  # def filters
  #   return if @filters.blank?
  #
  #   @filters.map do |filter|
  #     {
  #       value: filter,
  #       title: t("custom.projekts.orders.#{filter}")
  #     }
  #   end
  # end

  # def current_filter_option
  #   return if filters.blank?
  #
  #   filters.find { |filter_option| filter_option[:value] == @current_filter }
  # end

  # def html_class(order)
  #   "is-active" if order == current_order
  # end
  # def filter_link_path(order)
  #   current_path_with_query_params(order: order, anchor: @anchor)
  # end

  def tag_name(order)
    if order == current_order
      :h2
    else
      :span
    end
  end

  def title_for(order)
    t("custom.projekts.orders.#{order}_title")
  end

  def link_text(order)
    t("custom.projekts.orders.#{order}")
  end
end
