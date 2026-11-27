class Whatsapp::ReachableContributionsQuery
  # What the chat may reach by id, as against what it chooses to show. The
  # searches and lists are already scoped to what the portal lists, but an id
  # can arrive from anywhere — a pill sent weeks ago, a row the model composed,
  # a number it made up — and a bare find_by on it named, opened, supported or
  # commented on other people's drafts and proposals still awaiting moderation.
  #
  # Two sets, because the citizen's own contribution is theirs to look at before
  # moderation has decided on it but not to support or comment on: the portal
  # offers neither on a proposal it does not list yet, author included.
  #
  # Built from the portal's own scopes rather than restating their conditions,
  # so a change to moderation changes this with it.

  # Published or the citizen's own. Own means published by them: a draft that
  # was never sent in is not a contribution under review, and opening one would
  # tell them it was.
  def self.openable_proposals(user:)
    listed = listed_proposals

    return listed if user.blank?

    listed.or(::Proposal.published.created_by(user))
  end

  # A draft investment is already out of reach through the model's default
  # scope, so the citizen's own are every one they sent in.
  def self.openable_investments(user:)
    listed = listed_investments

    return listed if user.blank?

    listed.or(::Budget::Investment.where(author: user))
  end

  # What may be supported or commented on: what the portal lists, for everyone.
  def self.actionable_proposals
    listed_proposals
  end

  # Only inside projekts an anonymous visitor can see, so a search never names
  # a contribution of a draft or group-restricted projekt.
  def self.listed_proposals
    ::Proposal
      .base_selection
      .where(projekt_phase_id: publicly_visible_phase_ids)
  end

  def self.listed_proposal?(proposal)
    proposal.present? && listed_proposals.exists?(id: proposal.id)
  end

  def self.listed_investments
    ::Budget::Investment
      .not_unfeasible
      .where(budget_id: ::Budget.where(projekt_phase_id: publicly_visible_phase_ids).select(:id))
  end

  def self.publicly_visible_phase_ids
    ::ProjektPhase.of_publicly_visible_projekt.unscope(:order).select(:id)
  end

  private_class_method :publicly_visible_phase_ids
end
