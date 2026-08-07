class Whatsapp::Steps::SendDigestService < ApplicationService
  MAX_SHOWN = 5

  # A digest is the reply for content whose items each have their own link:
  # events, polls, milestones, contributions. A list cannot carry those — its
  # rows need unique ids and can only trigger one of our own actions, and two
  # milestones of the same phase would collide on the same id.
  #
  # Entries are {title:, url:, description:}; url and description are optional.
  def initialize(conversation:, entries:, intro:, empty_body:, more_url: nil)
    @conversation = conversation
    @entries = entries
    @intro = intro
    @empty_body = empty_body
    @more_url = more_url
  end

  def call
    return send_empty if @entries.empty?

    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: [@intro, *formatted_entries, more_line].compact.join("\n\n"),
      actions: [:menu]
    )
  end

  private

    def formatted_entries
      @entries.first(MAX_SHOWN).map do |entry|
        ["*#{entry[:title]}*", entry[:description].presence, entry[:url].presence]
          .compact
          .join("\n")
      end
    end

    # Truncation is stated rather than silent: a digest that simply stops reads
    # as "that is all there is".
    def more_line
      hidden = @entries.size - MAX_SHOWN

      return if hidden <= 0
      return I18n.t("whatsapp.bot.menu.digest.more_plain", count: hidden) if @more_url.blank?

      I18n.t("whatsapp.bot.menu.digest.more", count: hidden, url: @more_url)
    end

    def send_empty
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: @empty_body,
        actions: [:menu]
      )
    end
end
