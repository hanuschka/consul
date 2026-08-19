class Ai::Tools::WhatsappAiAssistant::ReviseDraft < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The change the citizen asked for, written by the model that is already reading
  # the draft and the request. This used to be a second completion with a prompt of
  # its own: it read the draft, the correction and the taxonomy, and produced the
  # same edit — one model call further into a turn the citizen was waiting on, and
  # with none of the conversation in view.
  DESCRIPTION_LENGTH = 700

  description "Applies a change the citizen asked for to the draft on the table. Write the " \
              "revision yourself and pass only what changes: leave title empty when only the " \
              "text is affected, and the other way round. Change nothing they did not ask about " \
              "— a shorter title is not a reason to touch the text — and keep their subject, " \
              "their place and what they are asking for: you are editing their contribution, not " \
              "writing a better one of your own. The text is HTML and starts directly with a <p> " \
              "paragraph; it must not repeat the title and must not begin with a heading. Write " \
              "in the language the draft is written in. Returns the revised draft for you to show " \
              "them; nothing is published."

  params do
    optional :title,
      description: "The revised title, or empty to keep the current one." do
      string
    end
    optional :text,
      description: "The revised text as HTML starting with a <p> paragraph, or empty to keep the " \
                   "current one. Must not repeat the title." do
      string
    end
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_DRAFT_DECISION
  end

  def execute(title: nil, text: nil)
    return no_draft_error if draft_resource.blank?

    refusal = refuse_if_not_permitted

    return refusal if refusal.present?
    return nothing_to_change_error if title.blank? && text.blank?

    apply(title, text)
  end

  private

    # Written straight onto the record rather than back through the stash: the record
    # exists by the time anything can be revised, its on-create validations have
    # already run, and re-persisting from the stash would re-apply the generation's
    # own ids over choices the citizen has since corrected.
    #
    # The stored assessment is cleared with the text it was reached on, which is what
    # lets the publish treat a verdict that is present as "already judged, do not pay
    # for it twice".
    def apply(title, text)
      draft_resource.title = title if title.present?

      if text.present?
        draft_resource.description = text
        draft_resource.ai_evaluation_result = nil
      end

      return invalid_revision_error if !draft_resource.save

      # The stored shortening belonged to the previous text. Left in place it would be
      # quoted back beside a draft it no longer describes.
      store_revised_summary if text.present?

      {
        draft: {
          title: draft_resource.title,
          text: ::Whatsapp.plain_text(draft_resource.description, length: DESCRIPTION_LENGTH)
        },
        hint: "Show them the revised draft and ask whether it can go in now."
      }
    end

    def store_revised_summary
      conversation.store_revised_summary!(
        ::Whatsapp.plain_text(draft_resource.description, length: DESCRIPTION_LENGTH)
      )
    end

    def nothing_to_change_error
      { error: "Neither a title nor a text was given, so nothing would change. Write the " \
               "revision, or ask the citizen what they want changed if they have not said." }
    end

    def invalid_revision_error
      {
        error: "The portal refused the revision.",
        reason: draft_resource.errors.full_messages.first.to_s,
        hint: "Say what the problem is and write the revision differently, or ask the citizen " \
              "what they want instead."
      }
    end
end
