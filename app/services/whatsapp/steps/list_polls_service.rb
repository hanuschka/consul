class Whatsapp::Steps::ListPollsService < ApplicationService
  def initialize(conversation:, projekt: nil)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Steps::SendDigestService.call(
      conversation: @conversation,
      entries: entries,
      intro: I18n.t("whatsapp.bot.menu.polls.intro"),
      empty_body: I18n.t("whatsapp.bot.menu.polls.empty")
    )
  end

  private

    # Links to the poll rather than casting a vote: the bot may not vote on the
    # citizen's behalf, and a poll answer cannot be taken back.
    def entries
      Whatsapp::OpenPollsQuery.call(projekt: @projekt).map do |poll|
        {
          title: poll.name,
          description: description_for(poll),
          url: Rails.application.routes.url_helpers.poll_url(poll, **UrlOptions.default.to_h)
        }
      end
    end

    def description_for(poll)
      return if poll.ends_at.blank?

      I18n.t("whatsapp.bot.menu.polls.until", end_date: I18n.l(poll.ends_at.to_date))
    end
end
