class OnBehalfOfAccountMailer < ApplicationMailer
  helper :mailer

  # Sent once, to somebody who never asked for an account: staff submitted a contribution in their
  # name and the address had no account yet. The account is already confirmed, so this is not a
  # double opt-in step — it tells them the account exists and how to get into it.
  def account_created(user, reset_password_token)
    @user = user
    @token = reset_password_token
    @email_to = @user&.email
    return if @email_to.blank?

    I18n.with_locale(@user.locale.presence || I18n.default_locale) do
      mail(to: @email_to, subject: t("custom.on_behalf_of_account.mailers.account_created.subject"))
    end
  end
end
