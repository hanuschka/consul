class Whatsapp::Flows::ProjektContributionsService < Whatsapp::Flows::BaseService
  # What other citizens have submitted to one projekt, sent as the bot's own
  # message rather than handed to the assistant as facts to retell. Every entry
  # has to carry the link to the Beitrag it names, and a message the model
  # writes carries it only when the model chooses to — which is the difference
  # between a citizen reaching a Beitrag in one tap and reaching it never.
  #
  # Answered as text rather than as a tappable list for the same reason
  # ContributionsService is: a row would have to lead somewhere, WhatsApp
  # renders no link inside one, and the link is the whole point here.
  MAX_SHOWN = 5

  def initialize(conversation:, projekt:)
    super(conversation: conversation)
    @projekt = projekt
  end

  def call
    return send_empty if contributions.empty?

    Whatsapp::Send.text(
      account: account,
      body: [
        Whatsapp.phrase("whatsapp.bot.projekt_contributions.intro", projekt: projekt_title),
        *entries,
        more_line
      ].compact_blank.join("\n\n")
    )

    Whatsapp::Flows::MainMenuService.follow_up(conversation: @conversation)
  end

  private

    # The query already filters to what the projekt page lists and caps itself at
    # the row limit, so the five below is about how long one chat message may be
    # rather than about what may be shown.
    def contributions
      @contributions ||= Whatsapp::ProjektContributionsQuery.call(projekt: @projekt)
    end

    def entries
      contributions.first(MAX_SHOWN).map { |contribution| entry_for(contribution) }
    end

    # No absolute date: WhatsApp renders a German one as a phone number and
    # offers to call it, and the age is what the question was actually about.
    def entry_for(contribution)
      key =
        if contribution[:url].blank?
          "whatsapp.bot.projekt_contributions.entry_without_url"
        else
          "whatsapp.bot.projekt_contributions.entry"
        end

      I18n.t(
        key,
        title: contribution[:title],
        age: relative_age(contribution[:created_at]),
        url: contribution[:url]
      )
    end

    # Bucketed here rather than through distance_of_time_in_words, whose German
    # is nominative: wrapping its "5 Tage" in a "vor %{time}" line reads "vor 5
    # Tage". The dative belongs to the copy, so each unit is its own pluralised
    # key — the same shape the projekt countdowns use.
    #
    # Days up to a month, then months, then years: this dates a Beitrag in a
    # chat message, where nothing turns on the difference between five and six
    # weeks.
    def relative_age(created_at)
      key, count = age_key_and_count(created_at)

      I18n.t("whatsapp.bot.projekt_contributions.age.#{key}", count: count)
    end

    def age_key_and_count(created_at)
      days = (Time.current.to_date - created_at.to_date).to_i

      return [:today, 0] if days < 1
      return [:days, days] if days < 31

      months = days / 30

      return [:months, months] if months < 12

      [:years, months / 12]
    end

    def more_line
      remaining = contributions.size - MAX_SHOWN

      return if remaining < 1

      Whatsapp.phrase("whatsapp.bot.projekt_contributions.more", count: remaining)
    end

    def send_empty
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.projekt_contributions.empty", projekt: projekt_title)
      )
    end

    def projekt_title
      Whatsapp::ProjektLink.title(@projekt)
    end
end
