module Whatsapp::PublishedResourceUrl
  module_function

  # Nothing the bot publishes is reached through a request, so the host comes
  # from the app's canonical URL options rather than from the caller.
  def call(resource)
    helpers = Rails.application.routes.url_helpers
    options = UrlOptions.default.to_h

    if resource.is_a?(Budget::Investment)
      return helpers.budget_investment_url(resource.budget, resource, **options)
    end

    helpers.proposal_url(resource, **options)
  end
end
