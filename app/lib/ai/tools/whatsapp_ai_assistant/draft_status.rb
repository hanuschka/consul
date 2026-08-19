class Ai::Tools::WhatsappAiAssistant::DraftStatus < Ai::Tools::WhatsappAiAssistant::BaseTool
  # What the draft on the table already has and what it still needs, which is the
  # one thing the model cannot work out for itself: whether a picture is attached,
  # whether the phase even collects a pin, whether a category is still outstanding.
  #
  # It replaces the ordering the step machine used to guarantee. There is no
  # sequence any more, so the answer to "what is left to do" has to be a question
  # the assistant can ask rather than a position it is standing in.
  DESCRIPTION_LENGTH = 700

  description "Returns everything about the draft in this conversation: its title and text as " \
              "they stand, which phase it belongs to, whether a category or sentiment is still " \
              "needed, whether a picture is attached, whether this phase collects a picture or a " \
              "map pin at all, and whether the citizen has already said they have no photo or " \
              "named the place in words. Call it before asking them for anything about the draft " \
              "— it is the only way to avoid asking for something they have already given — and " \
              "before publishing, to be sure nothing is outstanding. Sends nothing."

  def execute
    return no_draft_error if !conversation.unsaved_submission?

    {
      phase: phase_description,
      title: draft_title,
      text: draft_text,
      persisted: draft_resource.present?,
      picture_attached: picture_attached?,
      outstanding: outstanding_requirements,
      picture: picture_status,
      location: location_status,
      citizens_own_words: conversation.last_idea_text
    }.compact
  end

  private

    def phase_description
      return if projekt_phase.blank?

      {
        projekt_phase_id: projekt_phase.id,
        projekt: projekt_title(projekt_phase.projekt),
        phase: projekt_phase.title,
        ends_in: ::Whatsapp::DatePhrase.relative(projekt_phase.end_date)
      }.compact
    end

    # Read off the record once it exists and off the stash before it does. The two
    # are the same draft at two moments: nothing can be written until the phase's
    # on-create validations can pass, so a draft waiting on a category has no
    # record yet.
    def draft_title
      return draft_resource.title if draft_resource.present?

      conversation.draft_data.to_h["title"]
    end

    def draft_text
      html = draft_resource.present? ? draft_resource.description : stashed_description

      ::Whatsapp.plain_text(html, length: DESCRIPTION_LENGTH).presence
    end

    def stashed_description
      conversation.draft_data.to_h["description"]
    end

    # What the phase's own validations demand and the draft does not carry. Asked of
    # the stash before the record exists, because those validations run exactly once
    # — at the first save — so there is no record yet to ask.
    def outstanding_requirements
      requirements = ::Whatsapp::DraftTaxonomy.requirements(projekt_phase)

      missing =
        if draft_resource.present?
          requirements.select { |requirement| requirement.missing_on?(draft_resource) }
        else
          requirements.reject { |requirement| requirement.satisfied_by?(conversation.draft_data.to_h) }
        end

      return if missing.empty?

      missing.map { |requirement| requirement_row(requirement) }
    end

    # The options travel with the requirement, each with the action id that answers
    # it, so the model offers what the phase really has rather than a paraphrase of
    # it. A phase that offers more than three has to be a list.
    def requirement_row(requirement)
      {
        needs: requirement.kind.to_s,
        options: requirement.options.map do |option|
          { label: option.name, action_id: "#{requirement.kind}-#{option.id}" }
        end
      }
    end

    def picture_attached?
      draft_resource&.image&.attachment&.attached? == true
    end

    def picture_status
      return "not collected by this phase" if !conversation.image_question_available?
      return "attached" if picture_attached?
      return "the citizen said they have no photo" if conversation.photo_declined?

      "still open"
    end

    def location_status
      return "not collected by this phase" if !conversation.location_question_available?
      return "the citizen already named the place in words" if conversation.location_stated?
      return "a shared pin is waiting — call set_draft_location" if
        conversation.shared_location.present?

      "still open"
    end
end
