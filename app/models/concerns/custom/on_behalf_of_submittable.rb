module OnBehalfOfSubmittable
  extend ActiveSupport::Concern

  included do
    # Filled in by staff on the internal forms next to on_behalf_of. They are not stored on the
    # resource: the email resolves to the User the resource gets attributed to, and the company
    # name is kept on that user's profile.
    attr_accessor :on_behalf_of_company_name, :on_behalf_of_email

    validates :on_behalf_of_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

    # After the commit rather than after the create: the mail links to this resource, so the job
    # must not start before the row is visible to the worker, and a resource that never persists
    # must not produce a mail about a contribution nobody can open.
    after_create_commit :deliver_on_behalf_of_account_mail

    after_validation :report_stranded_on_behalf_of_account, on: :create
  end

  def author_name
    return User.human_attribute_name(:guest) if author.guest?

    on_behalf_of.presence || author.name
  end

  def author_initial
    if on_behalf_of.present?
      on_behalf_of.chars&.first&.upcase
    else
      author.first_letter_of_name
    end
  end

  private

    # Tells somebody whose account was opened for them by staff that it exists, and points them at
    # the contribution that caused it. Only for an account opened for this very submission:
    # created_on_behalf_of is set by Users::OnBehalfOfAccountService and lives on the in-memory
    # user, so a later submission for an address that already has an account stays silent.
    #
    # That also means the flag only survives when the author is assigned as an object, the way
    # OnBehalfOfAccountLinking does it. Assigning author_id instead loses it and skips the mail
    # without raising.
    def deliver_on_behalf_of_account_mail
      return unless author&.created_on_behalf_of

      OnBehalfOfAccountMailer
        .account_created(author, author_reset_password_token, self)
        .deliver_later
    end

    # Fires when the save that should have committed this resource fails validation after the
    # account was already opened: the controllers run link_on_behalf_of_account between valid? and
    # save, so a validation that only fails once the author is assigned strands the account —
    # committed, confirmed, random password, and no mail, because the mail waits for this commit.
    # The resubmit does not heal it: the address now has an account, so the service finds instead
    # of creates, created_on_behalf_of is never set again, and the mail is skipped for good. Nobody
    # in that story ever sees an error, hence the report.
    #
    # The flag guard keeps this quiet for every ordinary validation failure, including the
    # controllers' own valid? call, which runs before an author is assigned.
    def report_stranded_on_behalf_of_account
      return if errors.blank? || !author&.created_on_behalf_of
      return if !defined?(Sentry)

      Sentry.capture_message(
        "On behalf of account stranded: account committed but its resource failed to save",
        level: :warning,
        extra: {
          resource_class: self.class.name,
          author_id: author.id,
          validation_errors: errors.full_messages.join("; ").first(500)
        }
      )
    end

    # The same token Devise mints for a password reset, so the mail can link straight into the
    # password form instead of asking for the address a second time. Only the raw half works as a
    # link parameter and it cannot be read back off the record, so it is returned here rather than
    # read off the user later. Minted at send time, so an account whose resource never committed
    # is not left carrying a reset stamp for a mail that was never sent.
    def author_reset_password_token
      raw, encrypted = Devise.token_generator.generate(User, :reset_password_token)

      author.update_columns(reset_password_token: encrypted, reset_password_sent_at: Time.now.utc)

      raw
    end
end
