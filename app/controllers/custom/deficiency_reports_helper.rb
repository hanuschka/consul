module DeficiencyReportsHelper
  def css_for_deficiency_report_info_row(dr)
    if dr.image.present?
      "small-12 medium-6 large-7 column"
    else
      "small-12 medium-9 column"
    end
  end

  def all_deficiency_report_map_locations(deficiency_reports_for_map)
    ids = deficiency_reports_for_map.except(:limit, :offset, :order).ids.uniq

    MapLocation.where(mappable_id: ids, mappable_type: "DeficiencyReport").map do |map_location|
      map_location.features_json_data
    end
  end

  def deficiency_reports_default_view?
    @view == "default"
  end

  def deficiency_reports_minimal_view_path
    deficiency_reports_path(view: deficiency_reports_secondary_view)
  end

  def deficiency_reports_current_view
    @view
	end

  def deficiency_reports_secondary_view
    deficiency_reports_current_view == "default" ? "minimal" : "default"
  end

  def deficiency_report_all_responsible_sorted
    DeficiencyReport::OfficerGroup.all.order(:name) +
      DeficiencyReport::Officer.joins(:user).order("users.username ASC")
  end
end
