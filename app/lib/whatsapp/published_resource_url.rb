module Whatsapp::PublishedResourceUrl
  module_function

  # Nothing the bot publishes is reached through a request, so the host comes
  # from the app's canonical URL options rather than from the caller.
  #
  # Nil for anything the public cannot open yet — a proposal still awaiting
  # moderation, a hidden or unfeasible investment. Every caller names the
  # resource without a link in that case, which is worth more to the citizen
  # than a link onto an error page or a login wall.
  def call(resource)
    return if !publicly_visible?(resource)

    helpers = Rails.application.routes.url_helpers
    options = UrlOptions.default.to_h

    if resource.is_a?(::Comment)
      return comment_url(resource, helpers: helpers, options: options)
    end

    if resource.is_a?(Budget::Investment)
      return helpers.budget_investment_url(resource.budget, resource, **options)
    end

    helpers.proposal_url(resource, **options)
  end

  # A comment has no page of its own — it lives on the one it was written under,
  # so the address is that page with the comment's own anchor on it. Nil when what
  # it hangs off is not something this can address: the anchor alone would send a
  # citizen to a page that is not there.
  def comment_url(comment, helpers:, options:)
    commentable = comment.commentable

    return if !commentable.is_a?(::Proposal)

    helpers.proposal_url(commentable, **options, anchor: "comment_#{comment.id}")
  end

  # Asked through the portal's own scopes rather than by restating their
  # conditions: base_selection is what a projekt page lists, and a second
  # definition of "publicly visible" living here would drift from it the first
  # time moderation changes. Budget::Investment is acts_as_paranoid on
  # hidden_at, so its default scope already answers half the question.
  def publicly_visible?(resource)
    return false if resource.blank?

    # A comment hidden by a moderation rule on creation is exactly the case the
    # caller must not offer a link for, and #hidden? is the row's own answer —
    # this portal publishes comments immediately and hides them afterwards, so the
    # question cannot be asked of a setting.
    return !resource.hidden? if resource.is_a?(::Comment)

    if resource.is_a?(Budget::Investment)
      return ::Budget::Investment.not_unfeasible.exists?(id: resource.id)
    end

    ::Proposal.base_selection.exists?(id: resource.id)
  end
end
