class Brevo::MemberRevoker < ApplicationService
  # Runs the account through the same erasure an admin triggers in /adm — personal data nulled,
  # contributions kept anonymised — because a member leaving the association is a GDPR deletion,
  # not a moderation action.
  #
  # Staff accounts are never touched. An admin or manager who is also on the member list would
  # otherwise be erased by a list edit, and #erase strips roles on the way out, so the mistake
  # would not be undoable from the interface.
  Result = Struct.new(:erased, :email, :skipped_reason, keyword_init: true) do
    def erased?
      erased.present?
    end
  end

  def initialize(user, reason: nil)
    @user = user
    @reason = reason
  end

  def call
    return Result.new(erased: false, skipped_reason: :already_erased) if @user.erased?
    return Result.new(erased: false, email: @user.email, skipped_reason: :staff) if @user.staff?

    # The address is gone the moment #erase runs, so it is read out first for the sync log.
    email = @user.email
    @user.erase(@reason)
    release_contact

    Result.new(erased: true, email: email)
  end

  private

    # The mapping dies with the account: the contact is no longer a member, and clearing it keeps
    # the erased account out of the next run's deletion candidates and out of the way of a later
    # contact that reuses the id.
    def release_contact
      @user.update_columns(brevo_contact_id: nil, brevo_synced_at: Time.current)
    end
end
