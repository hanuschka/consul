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

    MapLocation.where(deficiency_report_id: ids).map do |map_location|
      map_location.shape_json_data.presence || map_location.json_data
    end
  end

  def json_data
    deficiency_report = DeficiencyReport.find(params[:id])

    image_url = deficiency_report.image.present? ? url_for(deficiency_report.image.attachment.variant(resize_to_fill: [221, 170], format: "jpeg", saver: { strip: true, interlace: "JPEG", quality: 80 })) : nil

    data = {
      deficiency_report_id: deficiency_report.id,
      image_url: image_url,
      deficiency_report_title: deficiency_report.title
    }.to_json

    respond_to do |format|
      format.json { render json: data }
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
