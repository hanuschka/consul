class Whatsapp::Steps::SendHelpService < ApplicationService
  # WhatsApp caps an interactive message's body at 1024 characters and rejects
  # anything longer outright, so the explainer is written to stay well inside it
  # rather than trusting the copy to behave.
  MAX_BODY_LENGTH = 1000

  # What the bot itself can do, answered in the chat. The portal's Hilfe page is
  # about participating on the website and never mentions WhatsApp, so linking
  # to it alone answered a question nobody asked.
  #
  # The prose is hand-written because the useful parts are not in the menu:
  # that a voice message works as well as text, that a draft is shown before
  # anything is submitted, that it can be revised. Which capabilities are
  # currently empty is added from live data, so a quiet week reads as "nothing
  # right now" instead of as a bot that cannot do it at all.
  EMPTY_CHECKS = {
    events: -> { WhatsappUpcomingEventsQuery.call.empty? },
    polls: -> { WhatsappOpenPollsQuery.call.empty? },
    results: -> { WhatsappPublishedResultsQuery.call.empty? },
    milestones: -> { WhatsappPublishedMilestonesQuery.call.empty? },
    create: -> { WhatsappEligiblePhasesQuery.call.empty? }
  }.freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: body.truncate(MAX_BODY_LENGTH),
      actions: [:menu]
    )
  end

  private

    def body
      [
        I18n.t("whatsapp.bot.menu.help.intro"),
        empty_line,
        help_page_line
      ].compact_blank.join("\n\n")
    end

    # Named with the very titles the menu rows use, so the two can never
    # describe the same capability differently.
    def empty_line
      names = EMPTY_CHECKS.filter_map do |action, empty|
        I18n.t("whatsapp.bot.menu.rows.portal.#{action}.title") if empty.call
      end

      return if names.empty?

      I18n.t("whatsapp.bot.menu.help.currently_empty", items: names.join(", "))
    end

    def help_page_line
      return if help_page.blank?

      I18n.t("whatsapp.bot.menu.help.more", url: help_page_url)
    end

    def help_page
      return @help_page if defined?(@help_page)

      @help_page =
        SiteCustomization::Page
          .where(status: "published", slug: Whatsapp::Steps::SendStaticPageService::SLUGS_BY_KEY[:help])
          .first
    end

    def help_page_url
      Rails.application.routes.url_helpers.page_url(
        id: help_page.slug, **UrlOptions.default.to_h
      )
    end
end
