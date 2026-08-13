class OnBehalfOfAccountMailer < ApplicationMailer
  helper :mailer

  # Scopes the signature of the preview links this mailer mints, so they only ever verify as what
  # they are. Read back by ApplicationController#on_behalf_of_preview_gid.
  PREVIEW_PURPOSE = "on_behalf_of_preview".freeze

  # Long enough to still be useful to somebody who gets round to reading the mail late, short enough
  # that a link forwarded on or left sitting in a mailbox does not stay live for good.
  PREVIEW_EXPIRY = 30.days

  # Sent once, to somebody who never asked for an account: staff submitted a contribution in their
  # name and the address had no account yet. The account is already confirmed, so this is not a
  # double opt-in step — it tells them the account exists and how to get into it.
  # The resource defaults to nil so that jobs enqueued by an older revision, which passed two
  # arguments, still deliver after a deploy instead of failing in the queue.
  def account_created(user, reset_password_token, resource = nil)
    @user = user
    @token = reset_password_token
    @resource = resource
    @resource_url = public_url_for(resource)
    @email_to = @user&.email
    return if @email_to.blank?

    I18n.with_locale(@user.locale.presence || I18n.default_locale) do
      mail(to: @email_to, subject: t("custom.on_behalf_of_account.mailers.account_created.subject"))
    end
  end

  private

    # Every model that reaches this mailer today has a public show route, but OnBehalfOfSubmittable
    # covers a couple that do not yet. A missing route must not lose the mail: knowing the account
    # exists and how to get into it is worth sending on its own.
    #
    # The preview token is what makes the link work at all for the three resource types that stay
    # hidden until an admin accepts them — the recipient is not logged in and has no password yet.
    def public_url_for(resource)
      return if resource.blank?

      preview_token = ResourcePreviewToken.generate(
        resource, purpose: PREVIEW_PURPOSE, expires_in: PREVIEW_EXPIRY
      )

      polymorphic_url(resource, preview_token: preview_token)
    rescue NoMethodError, ActionController::UrlGenerationError => e
      report_missing_resource_link(resource, e)
      nil
    end

    # The rescue above is broad enough to also swallow a regression — an investment whose budget is
    # gone fails with the same NoMethodError as a genuinely unrouted model — and the only symptom is
    # a mail with one paragraph missing, which nobody reports. So the degraded mail announces itself.
    def report_missing_resource_link(resource, error)
      return if !defined?(Sentry)

      Sentry.capture_message(
        "On behalf of account mail sent without a link to its resource",
        level: :warning,
        extra: {
          resource: "#{resource.class.name}##{resource.id}",
          error: "#{error.class}: #{error.message.to_s.first(200)}"
        }
      )
    end
end
