class Whatsapp::Flows::SubmitProposalService < ApplicationService
  # "I want to submit something" before a projekt is chosen. What comes back
  # depends only on how many phases are open, and each count needs a different
  # message: one projekt is named and offered, several are listed to choose
  # from, none is a dead end that has to say when it will end.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return send_no_open_phase if open_phases.empty?
    return Whatsapp::Flows::DiscoveryService.call(conversation: @conversation) if
      open_phases.size > 1

    Whatsapp::Flows::ProposalPromptService.call(
      conversation: @conversation, projekt_phase: open_phases.first
    )
  end

  private

    # An unlinked number is only offered what it can actually finish. Listing
    # every open phase and refusing the tap would be a worse answer than a
    # shorter list, and for most portals the shorter list is empty — which the
    # no-open-phase message already covers.
    def open_phases
      return @open_phases if defined?(@open_phases)

      @open_phases =
        if @conversation.user.present?
          Whatsapp::EligiblePhasesQuery.call
        else
          Whatsapp::EligiblePhasesQuery.guest_open
        end
    end

    # Named rather than left open-ended: the citizen is already subscribed to
    # the new-projekt notification by default, so the honest answer is that they
    # will hear about the next one without doing anything.
    def send_no_open_phase
      @conversation.reset_flow!

      Whatsapp::Outbound.text(
        account: @conversation.whatsapp_account,
        body: I18n.t("whatsapp.bot.no_open_phase_notice")
      )
    end
end
