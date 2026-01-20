module AdmHelper
  include Pagy::Frontend

  def restriction_label_for(projekt_phase)
    restrictions = []
    restrictions << I18n.t("adm.projekt_phases.projekt_phase.restrictions.user_status.#{projekt_phase.user_status}") if projekt_phase.user_status.present?
    restrictions << projekt_phase.geozone_restrictions_formatted if projekt_phase.geozone_restrictions.any?
    restrictions << projekt_phase.age_restriction_formatted if projekt_phase.age_restriction.present?
    restrictions.compact_blank.join(", ").presence || "-"
  end
end
