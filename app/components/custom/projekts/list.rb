class Projekts::List < ApplicationComponent
  def initialize(projekts:, all_projekts: nil, map_coordinates:, content_only: false, filters: nil, current_filter: nil, only_content: false)
    @projekts = projekts
    @map_coordinates = map_coordinates
    @current_filter = current_filter
    @filters = filters
    @only_content = only_content
  end

  def call
    render(Shared::ResourcesList.new(
      resources: @projekts,
      title: t("custom.resource_names_plular.projekt"),
      map_coordinates: @map_coordinates,
      wide: false,
      resources_url: list_projekts_url(limit: 3),
      current_filter_option: current_filter_option,
      filter_param: "order",
      filter_options: filter_options,
      only_content: @only_content,
      css_class: "js-projekts-list"
    ))
  end

  def filter_options
    @filters.map do |filter|
      [
        filter,
        t("custom.projekts.orders.#{filter}")
      ]
    end
  end

  def current_filter_option
    filter_options.find { |filter_option| filter_option[0] == @current_filter }
  end
end
