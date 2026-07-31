class Users::OnBehalfOfAccountService < ApplicationService
  # Resolves the email a staff member entered on an internal form into the User the resource
  # should be attributed to. An address without an account gets one, confirmed straight away —
  # the address was supplied by staff acting for the person, so there is no opt-in to collect, and
  # an unconfirmed account would leave them unable to log in. They are told about it by mail
  # instead. An address that already has an account is only looked up, so nobody receives an
  # unexpected mail about an account they already had.
  MAX_USERNAME_SUFFIX = 999

  Result = Struct.new(:user, :created, :error, keyword_init: true) do
    def success?
      error.blank?
    end

    def created?
      created.present?
    end
  end

  def initialize(email:, company_name: nil, name: nil)
    @email = email.to_s.strip.downcase
    @company_name = company_name.to_s.strip.presence
    @name = name.to_s.strip.presence
  end

  def call
    return Result.new if @email.blank?

    existing = User.with_hidden.find_by("LOWER(email) = ?", @email)
    return Result.new(error: :blocked_account) if existing&.hidden?
    return link(existing) if existing.present?

    create
  end

  private

    def link(user)
      user.update(company_name: @company_name) if @company_name.present? && user.company_name.blank?

      Result.new(user: user, created: false)
    end

    def create
      password = random_password

      user = User.new(
        email: @email,
        username: available_username,
        company_name: @company_name,
        password: password,
        password_confirmation: password,
        locale: I18n.locale.to_s,
        terms_data_storage: "1",
        terms_data_protection: "1",
        terms_general: "1",
        created_on_behalf_of: true
      )
      user.skip_confirmation!

      return Result.new(error: user.errors.full_messages.to_sentence) unless user.save

      OnBehalfOfAccountMailer.account_created(user).deliver_later

      Result.new(user: user, created: true)
    end

    # The account holder never sees this password. They set their own through the password reset
    # flow, which is what the mail above points them to.
    def random_password
      "#{SecureRandom.alphanumeric(20)}aA1!"
    end

    def available_username
      full = username_base.truncate(User.username_max_length, omission: "")
      return full if username_available?(full)

      stem = username_base.truncate(User.username_max_length - 5, omission: "")
      suffix = (2..MAX_USERNAME_SUFFIX).find { |number| username_available?("#{stem} #{number}") }

      "#{stem} #{suffix || SecureRandom.hex(2)}"
    end

    def username_base
      candidate = (@name || @email.split("@").first.tr("._-", " ")).squish

      candidate.presence || User.model_name.human
    end

    def username_available?(username)
      User.with_hidden.where("LOWER(username) = ?", username.downcase).none?
    end
end
