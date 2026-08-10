class Whatsapp::Flows::ResumeRecapService < Whatsapp::Flows::BaseService
  # Sent before the step being resumed, never instead of it. The resume question
  # is answered hours or days after the citizen left, so what they land back on
  # has to say what it is about first.
  #
  # The draft is deliberately not repeated here: when one exists the resumed step
  # is the draft card itself, which carries the title and description one message
  # later, and only the projekt is missing from it. Without a draft nothing else
  # would say what the citizen had already typed, so the idea comes back with the
  # recap.
  IDEA_PREVIEW_LENGTH = 300

  def call
    return if projekt.blank?

    Whatsapp::Outbound.text(account: account, body: body)
  end

  private

    def projekt
      @conversation.projekt_phase&.projekt
    end

    def body
      recap = I18n.t(
        "whatsapp.bot.proposal.resume_recap", projekt: Whatsapp::ProjektLink.title(projekt)
      )

      [recap, idea_recap].compact_blank.join("\n\n")
    end

    # The text the citizen sent before the generation call, kept by
    # BuildDraftService for its own retry path. Read rather than stored a second
    # time: a draft that failed to generate leaves exactly this behind, which is
    # the case the citizen most needs quoted back.
    def idea_recap
      return if @conversation.draft_resource.present?

      idea_text = @conversation.context["last_idea_text"].to_s.squish

      return if idea_text.blank?

      I18n.t(
        "whatsapp.bot.proposal.resume_recap_idea",
        idea: idea_text.truncate(IDEA_PREVIEW_LENGTH)
      )
    end
end
