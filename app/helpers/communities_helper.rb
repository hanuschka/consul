module CommunitiesHelper
  def community_title(community)
    communitable_for(community)&.title.to_s
  end

  def community_text(community)
    if communitable_is_proposal?(community)
      t("community.show.title.proposal")
    else
      t("community.show.title.investment")
    end
  end

  def community_description(community)
    if communitable_is_proposal?(community)
      t("community.show.description.proposal")
    else
      t("community.show.description.investment")
    end
  end

  def author?(community, participant)
    communitable = communitable_for(community)
    return false if communitable.blank?

    communitable.author_id == participant.id
  end

  def community_back_link_path(community)
    communitable = communitable_for(community)

    if communitable.is_a?(Proposal)
      proposal_path(communitable)
    else
      budget_investment_path(communitable.budget_id, communitable)
    end
  end

  def community_access_text(community)
    if communitable_is_proposal?(community)
      t("community.sidebar.description.proposal")
    else
      t("community.sidebar.description.investment")
    end
  end

  def create_topic_link(community)
    if current_user.present?
      new_community_topic_path(community.id)
    else
      new_user_session_path
    end
  end

  private

  def communitable_for(community)
    @communitable_resource || community.communitable
  end

  def communitable_is_proposal?(community)
    communitable_for(community).is_a?(Proposal)
  end
end
