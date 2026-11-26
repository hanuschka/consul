class OfferMailer < ApplicationMailer
  helper :mailer

  def provider_reminder(provider, user)
    @provider = provider
    @user = user
    @offers = provider.offers.includes(:translations).sort_by_title

    return if user.email.blank?

    I18n.with_locale(I18n.default_locale) do
      mail(to: user.email,
           subject: t("custom.offer_mailer.provider_reminder.subject", provider: provider.name))
    end
  end
end
