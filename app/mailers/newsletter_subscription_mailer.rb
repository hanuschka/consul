class NewsletterSubscriptionMailer < ApplicationMailer
  helper :mailer

  # Options come through `with` params: on Ruby 3.2+ Rails 6.1 hands a mailer
  # action's keyword arguments over as a positional hash.
  def confirm(email)
    @user = params[:user]
    @unregistered_newsletter_subscriber = params[:unregistered_newsletter_subscriber]
    @unregistered_newletter_unsubscribe_token = @unregistered_newsletter_subscriber.unsubscribe_token

    # subject = t("custom.notification_service_mailers.projekt_questions.subject")
    subject = "Anmeldung zum Newsletter"
    mail(to: email, subject: subject)
  end
end
