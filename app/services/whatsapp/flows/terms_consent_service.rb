class Whatsapp::Flows::TermsConsentService < Whatsapp::Flows::BaseService
  # The terms and privacy acceptance the web form collects as a checkbox, asked
  # before the citizen is asked for content. It used to be no question at all:
  # the bot set `resource_terms` on the record itself and a phase whose model it
  # skipped refused the submission after draft generation, with the record's own
  # validation message and a loop back to the idea prompt (CON-2969).
  #
  # A step rather than a refusal, which is the whole point. RefuseParticipation
  # resets the flow, and a citizen who accepts has to land back inside the phase
  # they were entering with nothing re-asked — so this keeps projekt_phase_id and
  # hands straight back to AskIdeaService.
  #
  # Asked once per number ever, like the AI disclosure and for the same reason: a
  # regular who re-accepts on every submission stops reading what they accept.
  #
  # Two entry points rather than one with a mode, because the only thing that
  # differs is where accepting goes back to — and a caller reading
  # `ask(conversation:, origin: :publish)` could not tell you which of the two
  # sentences the citizen is about to be answered with.
  ORIGIN_IDEA = "idea".freeze
  ORIGIN_PUBLISH = "publish".freeze

  # Before the citizen is asked for content: accepting continues into the idea
  # prompt, which is where the flow was heading.
  def self.before_idea(conversation:)
    new(conversation: conversation, origin: ORIGIN_IDEA).ask
  end

  # Before a finished draft goes online. Reached by a submission that was
  # already in flight when the question was introduced: its record carries the
  # implicit `resource_terms = true` PersistDraftService writes, the models
  # validate that on create only, so nothing between here and publication would
  # ever have asked. Accepting resumes the publish.
  def self.before_publish(conversation:)
    new(conversation: conversation, origin: ORIGIN_PUBLISH).ask
  end

  # The question put again, with the origin the first asking recorded left
  # alone — a typed message at the step re-asks, and re-deciding where
  # accepting goes would send a citizen interrupted mid-publish back to the
  # idea prompt.
  def self.re_ask(conversation:)
    new(conversation: conversation, origin: conversation.terms_origin).ask
  end

  def self.accept(conversation:)
    new(conversation: conversation).accept
  end

  def self.decline(conversation:)
    new(conversation: conversation).decline
  end

  def initialize(conversation:, origin: nil)
    super(conversation: conversation)
    @origin = origin.presence || ORIGIN_IDEA
  end

  # `Send.question` rather than `Send.buttons`: this is a question, so "abbrechen"
  # typed instead of tapped has to be readable by the channel gate.
  def ask
    @conversation.ask_terms_consent!(@origin)

    Whatsapp::Send.question(
      conversation: @conversation,
      body: body,
      buttons: Whatsapp::FlowActions.terms_consent_buttons
    )
  end

  # Straight back into the step that sent us here. Both continuations re-check
  # the phase's own permissions on their way through, so a phase that closed
  # while the question sat unanswered still stops the submission.
  # The origin is read off the conversation, never from @origin: the tap arrives
  # through FlowActionDispatch, which knows only that a pill was tapped, so the
  # question's own record of where it was asked is the only thing that can
  # answer it.
  def accept
    account.mark_terms_accepted!

    origin = @conversation.terms_origin

    @conversation.clear_terms_origin!

    return resume_publish if origin == ORIGIN_PUBLISH

    Whatsapp::Flows::AskIdeaService.call(conversation: @conversation)
  end

  # The consequence in one sentence, then the menu. Not the idea prompt: the
  # citizen answered the question that was put to them, and asking for content
  # they have just been told cannot be submitted is the loop this whole step
  # exists to remove.
  def decline
    Whatsapp::Send.text(account: account, body: I18n.t("whatsapp.bot.terms_consent.declined"))

    @conversation.reset_flow!

    Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation)
  end

  private

    # The draft can be gone by the time the question is answered — a retention
    # purge, an admin deleting the phase — and the publish would then have
    # nothing to publish. The same answer the picker and the preview already
    # give a draft that is no longer there.
    def resume_publish
      if draft_resource.blank?
        return Whatsapp::Flows::ResumeOrRestartService.restart(conversation: @conversation)
      end

      Whatsapp::Flows::PublishResultService.call(conversation: @conversation)
    end

    # `I18n.t`, never `Whatsapp.phrase`. This is a legal declaration, and
    # PhrasingService serves a different wording per send — the same reason
    # `onboarding.consent` is kept out of it (see its OCCASIONAL_KEYS comment).
    # Both URLs go in the body because a CTA-url bubble carries exactly one
    # button and cannot be combined with the reply pills this question needs.
    def body
      I18n.t(
        "whatsapp.bot.terms_consent.ask",
        conditions_url: Whatsapp::PortalLinks.conditions_url,
        privacy_url: Whatsapp::PortalLinks.privacy_url
      )
    end
end
