class Whatsapp::Inbound::EntryTokenCapture
  # Stores what a QR deep link points at without sending anything — the
  # caller decides the reply (the login link first for unlinked numbers).
  # Mutating the conversation IS its job: a phase token starts the flow, a
  # projekt token with one open phase does too, several reset it and leave
  # the chosen projekt readable off #projekt.
  #
  # Its gate runs before the unlinked gate (a scanned QR gets the login link
  # first, and the captured flow survives for after linking) and before the
  # staleness gate: start_draft! restarts the flow clock, so a fresh scan is
  # never interrupted by a resume question about the draft it just replaced.
  def initialize(conversation:, reading:)
    @conversation = conversation
    @reading = reading
  end

  # The projekt behind a :projekt_choice capture, for the discovery list the
  # spine answers it with.
  attr_reader :projekt

  # nil, :phase, :projekt, :projekt_choice or :projekt_without_phase.
  def call
    capture_phase_token || capture_projekt_token
  end

  private

    def capture_phase_token
      projekt_phase_id = Whatsapp::QrToken.projekt_phase_id_from(@reading.text)

      return if projekt_phase_id.blank?

      projekt_phase = ::ProjektPhase.find_by(id: projekt_phase_id)

      return if projekt_phase.blank?

      @conversation.start_draft!(projekt_phase)

      :phase
    end

    def capture_projekt_token
      projekt_id = Whatsapp::QrToken.projekt_id_from(@reading.text)

      return if projekt_id.blank?

      scanned_projekt = ::Projekt.find_by(id: projekt_id)

      return if scanned_projekt.blank?

      store_projekt_entry(scanned_projekt)
    end

    # A phase QR code names the phase, so the citizen has already chosen. A
    # projekt QR code has chosen only the projekt: one open phase is started
    # into, several become a choice the caller has to put to them.
    def store_projekt_entry(scanned_projekt)
      eligible_phases = Whatsapp::EligiblePhasesQuery.call(projekt: scanned_projekt)

      return :projekt_without_phase if eligible_phases.empty?

      if eligible_phases.one?
        @conversation.start_draft!(eligible_phases.first)

        return :projekt
      end

      @conversation.discard_draft!
      @projekt = scanned_projekt

      :projekt_choice
    end
end
