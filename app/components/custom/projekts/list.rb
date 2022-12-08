class Projekts::List < ApplicationComponent
  def initialize(projekts:, all_projekts: nil, map_coordinates:, content_only: false, filters: nil, current_filter: nil, only_content: false, overview_page_mode: false, anchor: nil, standalone: false)
    @projekts = projekts
    @map_coordinates = map_coordinates
    @current_filter = current_filter
    @filters = filters
    @only_content = only_content
    @anchor = anchor
    @standalone = standalone
  end

  def call
    render(Shared::ResourcesList.new(
      resources: @projekts,
      title: t("custom.resource_names.projekt"),
      map_coordinates: @map_coordinates,
      wide: false,
      resources_url: list_projekts_url(limit: 3),
      current_filter_option: current_filter_option,
      filter_param: "order",
      filter_options: filter_options,
      only_content: @only_content,
      css_class: "js-projekts-list",
      standalone: @standalone,
      no_items_text: t('custom.projekts.index.no_projekts_for_current_filter')
    ))
  end

  def filter_options
    @filters.map do |filter|
      [
        filter,
        t("custom.projekts.orders.#{filter}"),
        filter_link_path(filter)
      ]
    end
  end

  def current_filter_option
    filter_options.find { |filter_option| filter_option[0] == @current_filter }
  end

  # def html_class(order)
  #   "is-active" if order == current_order
  # end

  def tag_name(order)
    if order == current_order
      :h2
    else
      :span
    end
  end

  def filter_link_path(order)
    current_path_with_query_params(order: order, anchor: @anchor)
  end

  def title_for(order)
    t("custom.projekts.orders.#{order}_title")
  end

  def link_text(order)
    t("custom.projekts.orders.#{order}")
  end
end
