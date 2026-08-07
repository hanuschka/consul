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
      @conversation.user
    end

    def available_actions
      actions = [:page]

      actions << :phases if WhatsappProjektPhasesQuery.exists?(projekt: @projekt)
      actions << :contributions if WhatsappProjektContributionsQuery.exists?(projekt: @projekt)
      actions << :events if WhatsappUpcomingEventsQuery.exists?(projekt: @projekt)
      actions << :milestones if WhatsappPublishedMilestonesQuery.exists?(projekt: @projekt)
      actions << :results if WhatsappPublishedResultsQuery.exists?(projekt: @projekt)
      actions << :follow if user.present?

      actions
    end
end
