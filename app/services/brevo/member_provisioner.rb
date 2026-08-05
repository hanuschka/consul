class Brevo::MemberProvisioner < ApplicationService
  # Turns one Brevo contact into a usable account: confirmed straight away, because membership was
  # established in the association's member list rather than by a signup here, with a password only
  # the member sets — through the token the invitation mail carries.
  #
  # An address that already has an account is only linked, never re-created and never mailed, so
  # re-running the sync cannot duplicate accounts or surprise anybody twice.
  #
  # Brevo attribute names differ per installation; the German ones are checked as well because that
  # is how this client's list is set up.
  FIRST_NAME_KEYS = %w[FIRSTNAME VORNAME].freeze
  LAST_NAME_KEYS = %w[LASTNAME NACHNAME NAME].freeze
  USERNAME_SUFFIX_LENGTH = 5

  Result = Struct.new(:user, :created, :error, keyword_init: true) do
    def success?
      error.blank?
    end

    def created?
      created.present?
    end
  end

  def initialize(contact)
    @contact = contact || {}
    @email = @contact["email"].to_s.strip.downcase
  end

  def call
    return Result.new if @email.blank?

    existing = User.with_hidden.find_by("LOWER(email) = ?", @email)
    return Result.new(error: :blocked_account) if existing&.hidden?

    existing.present? ? link(existing) : create_account
  end

  private

    def link(user)
      link_contact(user)

      Result.new(user: user, created: false)
    end

    def create_account
      password = "#{SecureRandom.alphanumeric(20)}aA1!"

      user = User.new(
        email: @email,
        username: available_username,
        password: password,
        password_confirmation: password,
        locale: I18n.locale.to_s,
        terms_data_storage: "1",
        terms_data_protection: "1",
        terms_general: "1",
        # A contact carries an address and at best a name, so the profile fields the public
        # registration form collects cannot be validated on this save.
        created_on_behalf_of: true
      )
      user.skip_confirmation!

      return Result.new(error: user.errors.full_messages.to_sentence) unless user.save

      link_contact(user)
      BrevoMemberMailer.invitation(user, reset_password_token(user)).deliver_later

      Result.new(user: user, created: true)
    end

    # A Brevo contact id maps to exactly one account. It can move — somebody changes the contact's
    # address in Brevo to one that already has an account here — and when it does the previous
    # holder stops being a member rather than the unique index blowing up the whole run. They keep
    # their account and their contributions; they just no longer get in through the member gate.
    def link_contact(user)
      contact_id = @contact["id"]
      return if contact_id.blank?
      return if user.brevo_contact_id == contact_id

      User.where(brevo_contact_id: contact_id).where.not(id: user.id).update_all(brevo_contact_id: nil)
      user.update_columns(brevo_contact_id: contact_id, brevo_synced_at: Time.current)
    end

    # The same token Devise mints for a password reset, so the invitation links straight into the
    # password form instead of asking for the address a second time. Only the raw half works as a
    # link parameter and it cannot be read back off the record, so it is returned to the caller.
    def reset_password_token(user)
      raw, encrypted = Devise.token_generator.generate(User, :reset_password_token)
      user.update_columns(reset_password_token: encrypted, reset_password_sent_at: Time.now.utc)

      raw
    end

    def available_username
      base = username_base.truncate(User.username_max_length, omission: "")
      return base if username_available?(base)

      stem = username_base.truncate(User.username_max_length - USERNAME_SUFFIX_LENGTH, omission: "")

      "#{stem} #{SecureRandom.hex(2)}"
    end

    def username_base
      attributes = @contact["attributes"].presence || {}
      name = [value_for(attributes, FIRST_NAME_KEYS), value_for(attributes, LAST_NAME_KEYS)]
             .compact_blank.join(" ")
      candidate = (name.presence || @email.split("@").first.tr("._-", " ")).squish

      candidate.presence || User.model_name.human
    end

    def value_for(attributes, keys)
      keys.filter_map { |key| attributes[key].presence }.first
    end

    def username_available?(username)
      User.with_hidden.where("LOWER(username) = ?", username.downcase).none?
    end
end
