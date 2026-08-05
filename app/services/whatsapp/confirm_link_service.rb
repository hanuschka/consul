class Whatsapp::ConfirmLinkService < ApplicationService
  def initialize(token:, user:, broadcast_consent: false)
    @token = token
    @user = user
    @broadcast_consent = broadcast_consent
  end

  def call
    return if account.blank?
    return if !account.link_token_valid?
    return if user_linked_to_other_number?

    account.update!(
      user: @user,
      state: "linked",
      verified_at: Time.current,
      link_token: nil,
      link_token_sent_at: nil,
      **consent_attributes
    )

    account
  end

  private

    def account
      @account ||= WhatsappAccount.find_by(link_token: @token.to_s)
    end

    # Linking is not consent to broadcasts: an account only enters the
    # broadcast audience when the citizen ticks the box on the link page.
    def consent_attributes
      return {} if !@broadcast_consent

      { opt_in_at: Time.current, opt_out_at: nil }
    end

    def user_linked_to_other_number?
      WhatsappAccount.where(user_id: @user.id).where.not(id: account.id).exists?
    end
end
