class Whatsapp::Flows::DiscoveryService < Whatsapp::Flows::BaseService
  # Catalog A1 and A3 — the same question, "show projects", answered for the
  # two kinds of number the dispatcher already tells apart. One service so the
  # two answers cannot drift into offering different portals.
  #
  # Linked (A1): rows are the phases that will actually accept a submission,
  # not every projekt that exists: the offer is made right after linking, and
  # an offer that leads to "you cannot take part here" would be a worse answer
  # than none. A tap goes straight into the proposal prompt for that phase,
  # which is the only thing the catalog does with a chosen projekt.
  #
  # Unlinked (A3): for a number that declined linking. It used to be a plain
  # digest of names and links on the reasoning that without an account there
  # is nothing to tap through to. Guest phases make that false: a phase set to
  # guest participation accepts a submission from anyone, so where one is open
  # this is the interactive list after all — and the only way to reach guest
  # participation without scanning a QR code.
  MAX_SHOWN = 5

  # `projekt_phases` is passed in by a caller that has already resolved them,
  # so the same query does not run twice for one tap.
  def self.linked(conversation:, projekt: nil, projekt_phases: nil)
    new(
      conversation: conversation, projekt: projekt, projekt_phases: projekt_phases
    ).linked
  end

  def self.unlinked(conversation:)
    new(conversation: conversation).unlinked
  end

  def initialize(conversation:, projekt: nil, projekt_phases: nil)
    super(conversation: conversation)
    @projekt = projekt
    @projekt_phases = projekt_phases
  end

  def linked
    Whatsapp::Flows::SendListService.call(
      conversation: @conversation,
      rows: linked_rows,
      body: linked_body,
      button_label: I18n.t("whatsapp.bot.discovery.button"),
      empty_body: empty_body
    )
  end

  # One projekt is a projekt the bot is pointing at, so it gets the card.
  # Several are a digest, and five cards would be five notifications for a
  # question that asked for an overview.
  def unlinked
    return send_guest_phases if guest_phases.any?
    return send_card if projekts.one?

    Whatsapp::Send.text(account: account, body: digest_body)
  end

  private

    # Scoped to one projekt when a QR code pointed at a projekt with several
    # open phases: the citizen already chose the projekt by scanning, and
    # offering them the whole portal again would throw that choice away.
    def linked_body
      if @projekt.blank?
        return Whatsapp.phrase("whatsapp.bot.discovery.body")
      end

      Whatsapp.phrase("whatsapp.bot.discovery.phase_body", projekt: Whatsapp::ProjektLink.title(@projekt))
    end

    def linked_rows
      phase_rows(@projekt_phases || Whatsapp::EligiblePhasesQuery.call(projekt: @projekt))
    end

    # One selectable row per open phase, titled by its projekt: a citizen
    # recognises the projekt, not the phase, while the tap has to carry the
    # phase. The linked list and the guest one differ only in which phases
    # they are handed, so both build their rows here.
    def phase_rows(projekt_phases)
      projekt_phases.map do |projekt_phase|
        {
          id: Whatsapp::FlowActions.id_for(action: :idea_start, param: projekt_phase.id),
          title: Whatsapp::ProjektLink.title(projekt_phase.projekt),
          description: row_description(projekt_phase)
        }
      end
    end

    # `title` rather than `name`: a phase's name is its type identifier —
    # ProposalPhase#name returns the literal "proposal_phase" — while `title` is
    # the tab name an admin gave it, falling back to the model's human name.
    def row_description(projekt_phase)
      return projekt_phase.title if projekt_phase.end_date.blank?

      I18n.t(
        "whatsapp.bot.discovery.row_description",
        phase: projekt_phase.title,
        end_date: Whatsapp::DatePhrase.absolute(projekt_phase.end_date)
      )
    end

    def guest_phases
      @guest_phases ||= Whatsapp::EligiblePhasesQuery.guest_open
    end

    def send_guest_phases
      Whatsapp::Flows::SendListService.call(
        conversation: @conversation,
        rows: phase_rows(guest_phases),
        body: Whatsapp.phrase("whatsapp.bot.discovery.guest_body"),
        button_label: I18n.t("whatsapp.bot.discovery.button"),
        empty_body: empty_body
      )
    end

    def send_card
      Whatsapp::Flows::SendProjektCardService.call(
        conversation: @conversation, projekt: projekts.first
      )
    end

    def digest_body
      return empty_body if projekts.empty?

      [
        Whatsapp.phrase("whatsapp.bot.discovery.public_intro"),
        entries,
        more_line
      ].compact_blank.join("\n\n")
    end

    def empty_body
      Whatsapp.phrase("whatsapp.bot.discovery.empty")
    end

    def projekts
      @projekts ||= Whatsapp::BrowsableProjektsQuery.call
    end

    def entries
      projekts.first(MAX_SHOWN).map do |projekt|
        I18n.t(
          "whatsapp.bot.discovery.entry",
          title: Whatsapp::ProjektLink.title(projekt),
          url: Whatsapp::ProjektLink.url(projekt)
        )
      end.join("\n\n")
    end

    # Truncation is stated rather than silent: a citizen who sees five names has
    # no way to tell whether that is all of them.
    def more_line
      remaining = projekts.size - MAX_SHOWN

      return if remaining < 1

      Whatsapp.phrase("whatsapp.bot.discovery.more", count: remaining, url: Whatsapp::PortalLinks.root_url)
    end
end
