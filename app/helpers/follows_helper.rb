module FollowsHelper
  def resource_follow_icon_visible?(resource)
    return false if current_user.blank?
    return false if current_user.guest?

    case resource
    when Proposal
      projekt_phase_feature?(resource.projekt_phase, "resource.show_follow_button_in_proposal_sidebar")
    else
      false
    end
  end

  def follow_text(followable)
    entity = followable.class.name.underscore
    t("shared.follow_entity", entity: t("activerecord.models.#{entity}.one").downcase)
  end

  def unfollow_text(followable)
    entity = followable.class.name.underscore
    t("shared.unfollow_entity", entity: t("activerecord.models.#{entity}.one").downcase)
  end
end
