class Whatsapp::Steps::ProjektMenuService < ApplicationService
  SUMMARY_LENGTH = 400

  def initialize(conversation:, projekt:)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Steps::SendMenuService.call(
      conversation: @conversation,
      scope: :projekt,
      record_id: @projekt.id,
      body: body,
      available_actions: available_actions
    )
  end

  private

    def body
      [
        "*#{Whatsapp::ProjektLink.title(@projekt)}*",
        subtitle,
        Whatsapp::ProjektLink.url(@projekt)
      ].compact_blank.join("\n\n")
    end

    def subtitle
      @projekt.page&.subtitle.presence&.squish&.truncate(SUMMARY_LENGTH)
    end

    def user
      @conversation.whatsapp_account.user
    end

    def available_actions
      actions = [:page]

      actions << :phases if WhatsappProjektPhasesQuery.call(projekt: @projekt).any?
      actions << :contributions if projekt_contributions.any?
      actions << :events if WhatsappUpcomingEventsQuery.call(projekt: @projekt).any?
      actions << :milestones if WhatsappPublishedMilestonesQuery.call(projekt: @projekt).any?
      actions << :results if WhatsappPublishedResultsQuery.call(projekt: @projekt).any?
      actions << :follow if user.present?

      actions
    end

    def projekt_contributions
      @projekt_contributions ||= WhatsappProjektContributionsQuery.call(projekt: @projekt)
    end
end
