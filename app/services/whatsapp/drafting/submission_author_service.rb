class Whatsapp::Drafting::SubmissionAuthorService < ApplicationService
  # Who a submission from this chat belongs to. A linked number authors as its
  # citizen. An unlinked one authors as a guest, but only where the phase allows
  # guest participation — everywhere else the answer is nobody, and the caller
  # asks for a link instead.
  #
  # The phase is read from the conversation rather than passed in: every caller
  # had only the conversation's own phase to give, and a second parameter that
  # can hold a different one lets "who authors this" and "which phase are we
  # validating against" disagree.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return @conversation.user if @conversation.user.present?
    return if !@conversation.projekt_phase&.guest_participation?

    Whatsapp::Accounts::GuestUserService.call(account: @conversation.whatsapp_account)
  end
end
