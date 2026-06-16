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

    MapLocation
      .with_deficiency_report_associations
      .where(mappable_id: ids)
      .map(&:features_json_data)
  end

  def deficiency_report_map_locations_count(deficiency_reports_for_map)
    ids = deficiency_reports_for_map.except(:limit, :offset, :order).ids.uniq

    MapLocation.where(mappable_type: "DeficiencyReport", mappable_id: ids).count
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

  def active_deficiency_report_confirmation_popup
    popup = DeficiencyReport::ConfirmationPopup.current
    popup.active? ? popup : nil
  end

  def deficiency_report_create_cta_button(css_class:, link_data: {}, style: nil)
    label = deficiency_reports_create_cta
    common = { class: css_class }
    common[:style] = style if style.present?

    if active_deficiency_report_confirmation_popup
      button_tag(label, **common, type: "button",
        data: { open: "deficiency-report-create-cta-modal" })
    else
      link_to(label, new_deficiency_report_path, **common, data: link_data)
    end
  end
end
