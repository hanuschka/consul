class Whatsapp::Steps::MainMenuService < ApplicationService
  # The portal's central navigation. Which rows appear is decided by what the
  # portal currently holds, so a quiet portal offers reading rather than a wall
  # of dead ends.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Steps::SendMenuService.call(
      conversation: @conversation,
      scope: :portal,
      body: ::Whatsapp.menu_greeting,
      available_actions: available_actions
    )
  end

  private

    def user
      @conversation.whatsapp_account.user
    end

    # Help and contact are the only rows that are always there: they are the
    # answer when nothing else is.
    def available_actions
      actions = %i[help contact]

      actions << :create if WhatsappEligiblePhasesQuery.call.any?
      actions << :polls if WhatsappOpenPollsQuery.call.any?
      actions << :projekts if WhatsappBrowsableProjektsQuery.call.any?
      actions << :events if WhatsappUpcomingEventsQuery.call.any?
      actions << :milestones if WhatsappPublishedMilestonesQuery.call.any?
      actions << :results if WhatsappPublishedResultsQuery.call.any?
      actions << :contributions if WhatsappUserContributionsQuery.call(user: user).any?
      actions << :notifications if user.present?

      actions
    end
end
