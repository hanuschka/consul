class Whatsapp::Flows::ProjektParticipationService < Whatsapp::Flows::BaseService
  # "I want to take part" before a projekt is chosen, and what that projekt
  # turns out to allow. One service because the two are one question asked in
  # two messages: the projekt is what decides which actions exist, so the
  # listing and the answer to a pick cannot be owned by different objects
  # without one of them re-deriving the other's set.
  #
  # The capability question here is about the *phase*, never about the citizen.
  # ProjektPhase#votable_by? and #comments_allowed? both answer false for a
  # number with no account (permission_problem returns :not_logged_in), so
  # building these buttons from them would hide supporting and commenting from
  # exactly the citizens who should be told an account is what they need. Who
  # may act is still decided where it always was — FlowActionDispatch's
  # ACCOUNT_ONLY_ACTIONS, and the phase's own restrictions at submission time.
  def self.ask_projekt(conversation:)
    new(conversation: conversation).ask_projekt
  end

  def self.offer_actions(conversation:, projekt:)
    new(conversation: conversation).offer_actions(projekt)
  end

  # Only projekts with something open to act in. An unlinked number is narrowed
  # further to the phases it could actually finish, the same narrowing
  # SubmitProposalService already makes: listing a phase and refusing the tap
  # is a worse answer than a shorter list.
  #
  # The step is written only once there is a list to answer. Written before the
  # count was known, it pinned the citizen on a question the bot had just said
  # it could not ask — every later message re-ran the step and got the same
  # dead end back.
  def ask_projekt
    return send_no_open_phase if projekts.empty?
    return offer_single_projekt if projekts.one?

    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_PARTICIPATION_PROJEKT)

    Whatsapp::Send.list(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.participation.choose_projekt"),
      button_label: I18n.t("whatsapp.bot.buttons.choose_projekt"),
      rows: projekt_rows
    )
  end

  # A projekt whose phases permit nothing is answered rather than offered an
  # empty button set: participation is over or has not started, and the link is
  # the only thing left to give (CON-2967).
  def offer_actions(projekt)
    @projekt = projekt
    @conversation.reset_flow!

    return send_closed if action_buttons.empty?

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase(
        "whatsapp.bot.participation.actions_body", projekt: Whatsapp::ProjektLink.title(projekt)
      ),
      buttons: action_buttons
    )
  end

  private

    # One projekt is a projekt the bot is already pointing at: asking which of
    # one is a question with a single answer, so it is skipped.
    def offer_single_projekt
      offer_actions(projekts.first)
    end

    # Read once and shared: #ask_projekt asks how many there are before it asks
    # what to call them, and the single-projekt case hands the same record on.
    def projekts
      @projekts ||= open_phases.map(&:projekt).uniq
    end

    def open_phases
      return Whatsapp::EligiblePhasesQuery.call if @conversation.user.present?

      Whatsapp::EligiblePhasesQuery.guest_open
    end

    def projekt_rows
      projekts.map do |projekt|
        {
          id: Whatsapp::FlowActions.id_for(action: :participate_projekt, param: projekt.id),
          title: Whatsapp::ProjektLink.title(projekt),
          description: I18n.t("whatsapp.bot.participation.row_description")
        }
      end
    end

    # Ordered as the menu row names them: submitting, supporting, commenting.
    # WhatsApp caps a button message at three, and three is exactly what the
    # widest projekt can offer.
    def action_buttons
      return @action_buttons if defined?(@action_buttons)

      @action_buttons = [
        submit_button,
        support_button,
        comment_button
      ].compact
    end

    def submit_button
      return if submittable_phase.blank?

      Whatsapp::FlowActions.button(
        action: :idea_start,
        label_key: "whatsapp.bot.buttons.submit_proposal",
        param: submittable_phase.id
      )
    end

    # The phase's own flag, asked of the phase rather than of a citizen. A
    # projekt with voting switched on but nothing submitted to it yet still
    # offers the button and is answered by the support flow's own "nothing to
    # support" — which is a truer answer than hiding the capability.
    def support_button
      return if !any_phase_with?("resource.allow_voting")

      Whatsapp::FlowActions.button(
        action: :support_prompt, label_key: "whatsapp.bot.buttons.support_prompt"
      )
    end

    def comment_button
      return if !any_phase_with?("resource.show_comments")

      Whatsapp::FlowActions.button(
        action: :comment_prompt, label_key: "whatsapp.bot.buttons.comment_prompt"
      )
    end

    # Every phase of the projekt, not only the ones the bot can submit to:
    # supporting and commenting live on phases EligiblePhasesQuery deliberately
    # excludes — a comment phase is not a submission phase, and a proposal
    # phase closed to new Beiträge can still be open for both.
    def projekt_phases
      @projekt_phases ||=
        Whatsapp::ProjektPhasesQuery.new(projekt: @projekt).call.select(&:current?)
    end

    def submittable_phase
      return @submittable_phase if defined?(@submittable_phase)

      @submittable_phase = projekt_phases.find do |projekt_phase|
        Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase) && submittable?(projekt_phase)
      end
    end

    # The bot can only submit where a guest may, when nobody is linked. Asked
    # here as well as in the listing because a projekt can also be reached by
    # QR code or by name, without passing the list.
    def submittable?(projekt_phase)
      return true if @conversation.user.present?

      projekt_phase.guest_participation?
    end

    def any_phase_with?(feature_key)
      projekt_phases.any? { |projekt_phase| projekt_phase.feature?(feature_key) }
    end

    # The same answer SubmitProposalService gives, and for the same reason: the
    # citizen is already subscribed to the new-projekt notification, so the
    # honest end of this is that they will hear about the next one.
    def send_no_open_phase
      @conversation.reset_flow!

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.no_open_phase_notice")
      )
    end

    def send_closed
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase(
          "whatsapp.bot.participation.closed",
          projekt: Whatsapp::ProjektLink.title(@projekt),
          url: Whatsapp::ProjektLink.url(@projekt)
        )
      )
    end
end
