class BrevoMemberMailer < ApplicationMailer
  helper :mailer

  # Sent once, when the member sync opens an account for a contact of the Brevo member list. The
  # account is already confirmed — membership was established in the association's member list, not
  # by a signup here — so this is not a double opt-in step. It tells the member the access exists
  # and carries the token they need to set their own password.
  def invitation(user, reset_password_token)
    @user = user
    @token = reset_password_token
    @email_to = @user&.email
    return if @email_to.blank?

    I18n.with_locale(@user.locale.presence || I18n.default_locale) do
      mail(to: @email_to, subject: t("custom.brevo_member.mailers.invitation.subject"))
    end
  end
end
