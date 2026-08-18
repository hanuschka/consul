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

    if resource.is_a?(Budget::Investment)
      return helpers.budget_investment_url(resource.budget, resource, **options)
    end

    helpers.proposal_url(resource, **options)
  end

  # Asked through the portal's own scopes rather than by restating their
  # conditions: base_selection is what a projekt page lists, and a second
  # definition of "publicly visible" living here would drift from it the first
  # time moderation changes. Budget::Investment is acts_as_paranoid on
  # hidden_at, so its default scope already answers half the question.
  def publicly_visible?(resource)
    return false if resource.blank?

    if resource.is_a?(Budget::Investment)
      return ::Budget::Investment.not_unfeasible.exists?(id: resource.id)
    end

    ::Proposal.base_selection.exists?(id: resource.id)
  end
end
