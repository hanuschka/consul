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

    MapLocation.deficiency_report_features(ids)
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

  def deficiency_report_officer_groups_only?
    Setting["deficiency_reports.officer_groups_only_for_assignment"].present?
  end

  # The officers an assignment field may offer. Whoever is already assigned stays in the list even
  # while the setting restricts assignment to groups: dropping them would mean the next save of an
  # unrelated change on that record silently clears a responsibility nobody meant to touch.
  def deficiency_report_assignable_officers(current_responsible = nil)
    officers = DeficiencyReport::Officer.joins(:user).order("users.username ASC")
    return officers unless deficiency_report_officer_groups_only?

    if current_responsible.is_a?(DeficiencyReport::Officer)
      officers.where(id: current_responsible.id)
    else
      officers.none
    end
  end

  def active_deficiency_report_confirmation_popup
    return nil unless DeficiencyReport.submissions_open?

    popup = DeficiencyReport::ConfirmationPopup.current
    popup.active? ? popup : nil
  end

  def deficiency_report_create_cta_button(css_class:, link_data: {}, style: nil)
    return unless DeficiencyReport.submissions_open?

    label = deficiency_reports_create_cta
    common = { class: css_class }
    common[:style] = style if style.present?

    if active_deficiency_report_confirmation_popup
      common[:class] = "#{css_class} js-shared-modal-open"

      button_tag(label, **common, type: "button",
        data: { shared_modal_id: "deficiency-report-create-cta-modal" })
    else
      link_to(label, new_deficiency_report_path, **common, data: link_data)
    end
  end
end
