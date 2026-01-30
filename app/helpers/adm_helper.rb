module AdmHelper
  include Pagy::Frontend

  def restriction_label_for(projekt_phase)
    restrictions = []
    restrictions << I18n.t("adm.projekt_phases.restrictions.user_status.#{projekt_phase.user_status}") if projekt_phase.user_status.present?
    restrictions << projekt_phase.geozone_restrictions_formatted if projekt_phase.geozone_restrictions.any?
    restrictions << projekt_phase.age_restriction_formatted if projekt_phase.age_restriction.present?
    restrictions.compact_blank.join(", ").presence || "-"
  end

  def projekt_phase_table_actions(projekt_phase)
    projekt_phase.admin_nav_bar_items.map do |action|
      {
        label: I18n.t("adm.projekt_phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekt_phase_path", projekt_phase)
      }
    end
  end

  def projekt_phase_tabs(projekt_phase, current_action: nil)
    current_action ||= action_name

    projekt_phase.admin_nav_bar_items.map do |action|
      {
        label: I18n.t("adm.projekt_phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekt_phase_path", projekt_phase),
        current: current_action == action
      }
    end
  end
end
