module CustomSearch
  extend ActiveSupport::Concern

  private

  def apply_filters(resources)
    @filtered_resources = resources
    apply_search
    apply_address_search
    apply_location_filter
    apply_date_filters
    apply_regular_filters

    @filtered_resources
  end

  def apply_search
    @filtered_resources = @filtered_resources.search(params[:search]) if params[:search].present?
  end

  def apply_address_search
    @filtered_resources = @filtered_resources.address_search(params[:address_search]) if params[:address_search].present?
  end

  def apply_location_filter
    return unless params[:coordinates].present?
    return unless @filtered_resources.class_name.in? %w[DeficiencyReport]

    coordinates = params[:coordinates].split(",").map(&:to_f)
    @filtered_resources = @filtered_resources.joins(:map_location).where(map_locations: { id: MapLocation.near(coordinates, 1).to_a.pluck(:id) })
  end

  def apply_date_filters
    date_min = safe_parse_date(params[:date_min])
    @filtered_resources = @filtered_resources.where("created_at >= ?", date_min) if date_min

    date_max = safe_parse_date(params[:date_max])
    @filtered_resources = @filtered_resources.where("created_at <= ?", date_max) if date_max
  end

  def safe_parse_date(date_string)
    return nil unless date_string.present?

    Date.parse(date_string)
  rescue Date::Error
    nil
  end

  def apply_regular_filters
    mapped_regular_filters_for(@filtered_resources.class_name).each do |mapped_filter|
      apply_regular_filter(mapped_filter)
    end
  end

  def apply_regular_filter(mapped_filter)
    @filtered_resources = @filtered_resources.where(mapped_filter[0] => params[mapped_filter[1]]) if params[mapped_filter[1]].present?
  end

  def mapped_regular_filters_for(resources_class_name)
    case resources_class_name
    when "DeficiencyReport"
      [[:deficiency_report_status_id, :status], [:deficiency_report_category_id, :category], [:deficiency_report_officer_id, :officer], [:admin_accepted, :approved]]
    end
  end
end
