class Whatsapp::Accounts::ConfirmLinkService < ApplicationService
  def initialize(token:, user:, broadcast_consent: false)
    @token = token
    @user = user
    @broadcast_consent = broadcast_consent
  end

  # Answers with the outcome rather than with the account or nil. The bot has to
  # say something different for each of the catalog's A5 and A6 branches, and a
  # bare nil made "your link expired" and "this number belongs to someone else"
  # indistinguishable to every caller.
  def call
    return ::ServiceResult.failure(error: :expired) if account.blank?
    return ::ServiceResult.failure(error: :expired) if !account.link_token_valid?

    return ::ServiceResult.failure(error: :already_linked) if user_linked_to_other_number?
    return ::ServiceResult.failure(error: :number_taken) if number_linked_to_other_user?

    account.update!(
      user: @user,
      state: "linked",
      verified_at: Time.current,
      link_token: nil,
      link_token_sent_at: nil,
      **consent_attributes
    )

    ::ServiceResult.success(account: account)
  end

  private

    def account
      @account ||= Whatsapp::Account.find_by(link_token: @token.to_s)
    end

    # Linking is not consent to broadcasts: an account only enters the
    # broadcast audience when the citizen ticks the box on the link page.
    def consent_attributes
      return {} if !@broadcast_consent

      { opt_in_at: Time.current, opt_out_at: nil }
    end

    def user_linked_to_other_number?
      Whatsapp::Account.where(user_id: @user.id).where.not(id: account.id).exists?
    end

    # The number's own side of the same question, which used to go unasked: a
    # confirmation for a number someone else had already verified overwrote that
    # linkage without telling either of them. Refused here, and undone only from
    # the chat — where the person holding the phone is the one tapping.
    def number_linked_to_other_user?
      account.user_id.present? && account.user_id != @user.id
    end
end
