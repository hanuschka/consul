class Whatsapp::Archive::MainMenuService < ApplicationService
  # The portal's central navigation. Which rows appear is decided by what the
  # portal currently holds, so a quiet portal offers reading rather than a wall
  # of dead ends.
  #
  # `body` is what the caller has to say before the choices — a confirmation, a
  # refusal, the end of a list. Every reply that used to end in a "Hauptmenü"
  # button now ends in the menu itself: the button cost a tap and a round trip
  # to reach the very rows it promised.
  def initialize(conversation:, body: nil)
    @conversation = conversation
    @body = body
  end

  def call
    ::Whatsapp::Archive::SendMenuService.call(
      conversation: @conversation,
      scope: :portal,
      body: @body.presence || ::Whatsapp.menu_greeting,
      empty_body: @body,
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
    # Every row is a yes/no question, so it is asked as one: this now runs for
    # every reply that carries the menu, not only when the citizen asks for it.
    def available_actions
      actions = %i[help contact]

      actions << :create if Whatsapp::EligiblePhasesQuery.exists?
      actions << :polls if Whatsapp::OpenPollsQuery.exists?
      actions << :projekts if Whatsapp::BrowsableProjektsQuery.exists?
      actions << :events if Whatsapp::UpcomingEventsQuery.exists?
      actions << :milestones if Whatsapp::PublishedMilestonesQuery.exists?
      actions << :results if Whatsapp::PublishedResultsQuery.exists?
      actions << :contributions if Whatsapp::UserContributionsQuery.exists?(user: user)
      actions << :notifications if user.present?

      actions
    end
end
