module CustomSearch
  extend ActiveSupport::Concern

  private

  def apply_filters(resources)
    @filtered_resources = resources
    @filtered_params = params.reject { |_, v| v.blank? }

    apply_search
    apply_address_search
    apply_date_filters
    apply_regular_filters

    @filtered_resources
  end

  def apply_search
    return unless @filtered_params[:search].present?

    @filtered_resources = @filtered_resources.search(@filtered_params[:search])
  end

  def apply_address_search
    return unless @filtered_params[:address_search].present?

    @filtered_resources = @filtered_resources.address_search(@filtered_params[:address_search])
  end

  def apply_date_filters
    date_min = safe_parse_date(@filtered_params[:date_min])
    @filtered_resources = @filtered_resources.where("created_at >= ?", date_min.beginning_of_day) if date_min

    date_max = safe_parse_date(@filtered_params[:date_max])
    @filtered_resources = @filtered_resources.where("created_at <= ?", date_max.end_of_day) if date_max
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
    return unless @filtered_params[mapped_filter[1]].present?

    @filtered_resources = @filtered_resources.where(mapped_filter[0] => @filtered_params[mapped_filter[1]])
  end

  def mapped_regular_filters_for(resources_class_name)
    case resources_class_name
    when "DeficiencyReport"
      [
        [:deficiency_report_status_id, :status],
        [:deficiency_report_category_id, :category],
        [:admin_accepted, :admin_accepted]
      ]
    end
  end
end
