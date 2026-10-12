# frozen_string_literal: true

class MunicipalPlans::TableComponent < ApplicationComponent
  COLUMN_KEYS = %i[title date topics districts badges].freeze
  SORTABLE_COLUMNS = {
    title: { ascending: "title", descending: "title_desc", first: :ascending },
    date: { ascending: "content_updated_at_asc", descending: "content_updated_at", first: :descending },
    topics: { ascending: "topics", descending: "topics_desc", first: :ascending },
    districts: { ascending: "districts", descending: "districts_desc", first: :ascending }
  }.freeze

  attr_reader :municipal_plans, :caption, :current_order

  def initialize(municipal_plans:, caption:, current_order: nil)
    @municipal_plans = municipal_plans
    @caption = caption
    @current_order = current_order
  end

  def caption_id
    @caption_id ||= "municipal-plans-table-caption-#{SecureRandom.hex(4)}"
  end

  def legend_label
    t("custom.municipal_plans.index.table.legend")
  end

  def badge_kinds
    MunicipalPlans::BadgesComponent::ICONS.keys
  end

  def badge_label(badge)
    t("custom.municipal_plans.badges.#{badge}")
  end

  def badge_icon(badge)
    MunicipalPlans::BadgesComponent::ICONS.fetch(badge, "circle")
  end

  def region_label
    t("custom.municipal_plans.index.table.region_label")
  end

  def label_for(key)
    t("custom.municipal_plans.index.table.columns.#{key}")
  end

  def sortable?(key)
    SORTABLE_COLUMNS.key?(key)
  end

  def sort_direction(key)
    SORTABLE_COLUMNS.fetch(key).slice(:ascending, :descending).key(current_order)
  end

  def aria_sort(key)
    sort_direction(key)&.to_s if sortable?(key)
  end

  def next_direction(key)
    first = SORTABLE_COLUMNS.fetch(key)[:first]
    return first unless sort_direction(key) == first

    first == :ascending ? :descending : :ascending
  end

  def sort_path(key)
    order = SORTABLE_COLUMNS.fetch(key)[next_direction(key)]
    helpers.current_path_with_query_params(order: order, page: nil)
  end

  def sort_hint(key)
    t("custom.municipal_plans.index.table.sort.#{next_direction(key)}")
  end

  def sort_icon(key)
    case sort_direction(key)
    when :ascending then "fa-sort-up"
    when :descending then "fa-sort-down"
    else "fa-sort"
    end
  end

  def formatted_date(municipal_plan)
    return if municipal_plan.content_updated_at.blank?

    l(municipal_plan.content_updated_at, format: "%d.%m.%Y")
  end
end
