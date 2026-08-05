class Whatsapp::LinkTokenService < ApplicationService
  TOKEN_BYTES = 24

  def initialize(account:)
    @account = account
  end

  def call
    return self.class.url_for(@account.link_token) if @account.link_token_valid?

    @account.update!(
      link_token: SecureRandom.urlsafe_base64(TOKEN_BYTES),
      link_token_sent_at: Time.current,
      state: "link_pending"
    )

    self.class.url_for(@account.link_token)
  end

  def self.url_for(token)
    Rails.application.routes.url_helpers.whatsapp_link_url(
      token: token,
      **UrlOptions.default.to_h
    )
  end
end
