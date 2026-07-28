require_dependency Rails.root.join("app", "helpers", "proposals_helper").to_s

module ProposalsHelper

  def all_proposal_map_locations(proposals_for_map)
    MapLocation.proposal_features(map_pin_proposal_ids(proposals_for_map))
  end

  # Callers only compare the result against a lazy-load threshold and never
  # display it, so counting stops one row past that threshold. Counting them
  # all is a semi-join over the entire filtered proposal relation and costs
  # ~440ms at production scale against ~14ms bounded.
  def proposal_map_pin_count_up_to(proposals_for_map, threshold, projekt_phase = nil)
    ids = map_pin_proposal_ids(proposals_for_map)
    count =
      MapLocation
        .where(mappable_type: "Proposal", mappable_id: ids)
        .limit(threshold + 1)
        .count

    return count if projekt_phase.blank?

    count + MasterportalPin.where(projekt_phase_id: projekt_phase.id).standalone.count
  end

  def map_pin_proposal_ids(proposals_for_map)
    proposals_for_map.select(:id)
  end

  def label_error_class?(field)
    return 'is-invalid-label' if @proposal.errors.any? && @proposal.errors[field].present?
    ""
  end

  def error_text(field)
    return @proposal.errors[:description].join(', ') if @proposal.errors.any? && @proposal.errors[field].present?
    ""
  end

  def default_active_proposal_footer_tab?(tab)
    return true if tab == "comments" && projekt_phase_feature?(@proposal.projekt_phase, "resource.show_comments")

    return true if tab == "notifications" && projekt_phase_feature?(@proposal.projekt_phase, "resource.enable_proposal_notifications_tab") &&
      !projekt_phase_feature?(@proposal.projekt_phase, "resource.show_comments")

    tab == "milestones" && projekt_phase_feature?(@proposal.projekt_phase, "resource.enable_proposal_milestones_tab") &&
      !projekt_phase_feature?(@proposal.projekt_phase, "resource.show_comments") &&
      !projekt_phase_feature?(@proposal.projekt_phase, "resource.enable_proposal_notifications_tab")
  end
end
