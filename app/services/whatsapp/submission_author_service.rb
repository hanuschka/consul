class Whatsapp::SubmissionAuthorService < ApplicationService
  # Who a submission from this chat belongs to. A linked number authors as its
  # citizen. An unlinked one authors as a guest, but only where the phase allows
  # guest participation — everywhere else the answer is nobody, and the caller
  # asks for a link instead.
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    return @conversation.user if @conversation.user.present?
    return if !guest_phase?

    Whatsapp::GuestUserService.call(account: @conversation.whatsapp_account)
  end

  private

    def guest_phase?
      @projekt_phase.present? && @projekt_phase.user_status == "guest"
    end
end
