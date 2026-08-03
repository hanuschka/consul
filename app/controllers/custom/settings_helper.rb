require_dependency Rails.root.join("app", "helpers", "settings_helper").to_s

module SettingsHelper
  def extended_feature?(name)
    setting["extended_feature.#{name}"].present?
  end

  def deficiency_reports_feature?(name)
    setting["deficiency_reports.#{name}"].presence
  end

  def deficiency_reports_feature_name
    Setting["deficiency_reports.feature_name"].presence ||
      t("custom.deficiency_reports.index.title")
  end

  def deficiency_reports_create_cta
    Setting["deficiency_reports.create_cta"].presence ||
      t("custom.deficiency_reports.index.start_deficiency_report")
  end

  def ideas_feature?(name)
    setting["ideas.#{name}"].presence
  end

  # form permissions

  # Single source of truth for "may this user submit this resource in somebody else's name?".
  # Both the forms and the controllers ask it, so a form can never offer an input the create
  # action then refuses. Takes the resource rather than a projekt because not every resource
  # belongs to one — deficiency reports are governed by their own manager role instead.
  #
  # Every OnBehalfOfSubmittable model carries the on_behalf_of accessors, but only the resources
  # whose controllers include OnBehalfOfAccountLinking consume them — anywhere else the address
  # would be collected and then dropped, so those forms must not offer the inputs at all.
  def allowed_to_post_on_behalf_of?(current_user, resource)
    return false if current_user.blank?
    return false unless resource.class.in?([Proposal, DeficiencyReport, Budget::Investment, Idea])
    return true if current_user.administrator?
    return current_user.deficiency_report_manager? if resource.is_a?(DeficiencyReport)
    return current_user.idea_manager? if resource.is_a?(Idea)
    return true if current_user.moderator?

    projekt = resource.projekt_phase&.projekt
    projekt.present? && current_user.projekt_manager? &&
      current_user.projekt_manager.allowed_to?(:create_on_behalf_of, projekt)
  end
end
