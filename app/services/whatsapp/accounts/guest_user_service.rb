class Whatsapp::Accounts::GuestUserService < ApplicationService
  # The author a submission gets when the phase allows guest participation and
  # the number never linked. Modelled on the web's guest user
  # (Custom::ApplicationController#initialize_guest_user) but built without a
  # request or a session, neither of which a webhook has, and kept on the
  # account instead of thrown away with the browser session.
  GUEST_USER_AGENT = "whatsapp-bot".freeze

  def initialize(account:)
    @account = account
  end

  def call
    return @account.guest_user if @account.guest_user.present?

    @account.update!(guest_user: existing_guest_user || create_guest_user)

    @account.guest_user
  end

  private

    # Keyed to the account rather than to the number: a wa_id in a username and
    # an email is the phone number written somewhere new, and there is no reason
    # to put it there.
    def guest_key
      "guest_whatsapp_#{@account.id}"
    end

    def guest_email
      "#{guest_key}@example.com"
    end

    def existing_guest_user
      ::User.find_by(email: guest_email, guest: true)
    end

    # The unique index on guest_user_id is the last word, but a duplicate email
    # can only come from a row this method has already made — adopt it rather
    # than fail the citizen's submission over it.
    def create_guest_user
      ::User.create!(guest_user_attributes)
    rescue ActiveRecord::RecordNotUnique
      existing_guest_user
    end

    def guest_user_attributes
      {
        username: guest_key,
        email: guest_email,
        guest: true,
        guest_user_agent: GUEST_USER_AGENT,
        terms_data_protection: true,
        terms_general: true,
        confirmed_at: Time.current,
        skip_password_validation: true
      }
    end
end
