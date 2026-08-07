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
      @conversation.user
    end

    # Help and contact are the only rows that are always there: they are the
    # answer when nothing else is.
    #
    # Every row is a yes/no question, so it is asked as one: the menu is the
    # most-sent message the bot has, and building each list only to count it
    # made it the most expensive one too.
    def available_actions
      actions = %i[help contact]

      actions << :create if WhatsappEligiblePhasesQuery.exists?
      actions << :polls if WhatsappOpenPollsQuery.exists?
      actions << :projekts if WhatsappBrowsableProjektsQuery.exists?
      actions << :events if WhatsappUpcomingEventsQuery.exists?
      actions << :milestones if WhatsappPublishedMilestonesQuery.exists?
      actions << :results if WhatsappPublishedResultsQuery.exists?
      actions << :contributions if WhatsappUserContributionsQuery.exists?(user: user)
      actions << :notifications if user.present?

      actions
    end
end
