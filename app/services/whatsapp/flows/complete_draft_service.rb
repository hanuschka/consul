class Whatsapp::Flows::CompleteDraftService < Whatsapp::Flows::BaseService
  # The gate between a generated draft and a persisted one, and the single place
  # that decides whether the citizen still has to answer something.
  #
  # It exists because the label and sentiment validations run only at creation:
  # once the record is written, nothing can make it valid, so everything they
  # need has to be in hand first. Until then the draft lives in the
  # conversation's context and this service asks for what is missing.
  #
  # Two entry points rather than one with a flag: the only thing that differs is
  # which copy the finished card carries.
  def self.for_first_draft(conversation:, inbound_message_id: nil)
    new(conversation: conversation, copy: :first, inbound_message_id: inbound_message_id).call
  end

  def self.for_revised_draft(conversation:, inbound_message_id: nil)
    new(conversation: conversation, copy: :revised, inbound_message_id: inbound_message_id).call
  end

  def initialize(conversation:, copy: :first, inbound_message_id: nil)
    super(conversation: conversation)
    @copy = copy
    @inbound_message_id = inbound_message_id
  end

  def call
    retry_missing_requirements

    return ask_for(missing_requirement) if ask_before_creating?

    # Nothing new to write: the citizen corrected a choice on a record that
    # already exists, and the stash was emptied when it was created.
    return present if draft_data.blank?

    @conversation.update!(draft_resource: persist)
    @conversation.merge_context!(draft_data: nil)

    present
  end

  private

    def draft_data
      @draft_data ||= @conversation.context["draft_data"].to_h
    end

    # Asked of the model once more before it is asked of the citizen: it was handed
    # the phase's options as a closed enum in the same call that wrote the title,
    # and a choice it could have made there is not worth a round trip in the chat.
    #
    # A loop because a phase can require both, and answering the category only
    # uncovers the sentiment behind it. It terminates on the attempt record rather
    # than on success: each requirement is marked before its call, so a second pass
    # can never retry the same one.
    def retry_missing_requirements
      while ask_before_creating? && retriable?(missing_requirement)
        retry_requirement(missing_requirement)
      end
    end

    # Once per requirement per conversation, recorded in the context rather than on
    # this instance: the service runs again on the citizen's next message, and
    # without the record a phase whose options the model keeps refusing would pay
    # for a retry on every message and still end at the same question.
    def retriable?(requirement)
      !retried_requirements.include?(requirement.to_s)
    end

    def retried_requirements
      Array(@conversation.context["retried_taxonomy"])
    end

    def retry_requirement(requirement)
      mark_retried(requirement)

      answer = Whatsapp::AiAssistant::TaxonomyRetryService.call(
        requirement: requirement,
        draft_data: draft_data,
        projekt_phase: @conversation.projekt_phase
      )

      return if answer.blank?

      store(answer)
    end

    # Marked before the call rather than after it, so a provider that times out
    # costs one attempt rather than one per message.
    def mark_retried(requirement)
      @conversation.merge_context!(
        retried_taxonomy: retried_requirements + [requirement.to_s]
      )
    end

    # Written back through the same key the generation call filled, so the answer
    # is re-read by exactly the validation that rejected the first one. Both
    # memoised reads are reassigned rather than left stale: the loop above and the
    # branch after it both ask again immediately.
    def store(answer)
      @draft_data = draft_data.merge(answer)
      @conversation.merge_context!(draft_data: @draft_data)
      @missing_requirement = derived_missing_requirement
    end

    # Only before the record exists. On a revision the record is already there,
    # so the on-create validations no longer run and a choice the citizen made
    # earlier is still on it — asking again would be asking twice.
    def ask_before_creating?
      @conversation.draft_resource.blank? && missing_requirement.present?
    end

    # What the resource's on-create validations demand and the drafting model
    # did not supply. Asked of the draft data rather than of a record, because
    # those validations run exactly once — at the first save — so there is no
    # record yet to ask.
    def missing_requirement
      return @missing_requirement if defined?(@missing_requirement)

      @missing_requirement = derived_missing_requirement
    end

    def derived_missing_requirement
      projekt_phase = @conversation.projekt_phase

      if Whatsapp::DraftCategory.required?(projekt_phase) &&
         Whatsapp::DraftCategory.valid_ids(draft_data, projekt_phase).empty?
        :category
      elsif Whatsapp::DraftSentiment.required?(projekt_phase) &&
            Whatsapp::DraftSentiment.valid_id(draft_data, projekt_phase).blank?
        :sentiment
      end
    end

    def ask_for(requirement)
      return Whatsapp::Flows::AskDraftChoiceService.category(conversation: @conversation) if
        requirement == :category

      Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation: @conversation)
    end

    def persist
      Whatsapp::Drafting::PersistDraftService.call(conversation: @conversation, draft_data: draft_data)
    end

    def present
      return Whatsapp::Flows::PresentDraftService.revised_draft(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      ) if @copy == :revised

      Whatsapp::Flows::PresentDraftService.first_draft(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      )
    end
end
