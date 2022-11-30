class Projekts::List < ApplicationComponent
  def initialize(projekts:, map_coordinates:, content_only: false)
    @projekts = projekts
    @map_coordinates = map_coordinates
    @content_only = content_only
  end

  def call
    render(Shared::ResourcesList.new(
      resources: @projekts,
      title: t("custom.welcome.active_projekt_cards.title"),
      map_coordinates: @map_coordinates,
      wide: false,
      resources_url: list_projekts_path(format: :js),
      filter_param: 'order',
      filter_options: filter_options,
      css_class: "js-projekts-list"
    ))
  end

  def filter_options
    Projekt::INDEX_FILTERS.map do |filter|
      [
        filter,
        t("custom.projekts.orders.#{filter}")
      ]
    end
  end
end
