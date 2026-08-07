class Whatsapp::Flows::CompleteDraftService < ApplicationService
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
    @conversation = conversation
    @copy = copy
    @inbound_message_id = inbound_message_id
  end

  def call
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

      projekt_phase = @conversation.projekt_phase

      @missing_requirement =
        if Whatsapp::DraftCategory.valid_ids(draft_data, projekt_phase).empty? &&
           Whatsapp::DraftCategory.required?(projekt_phase)
          :category
        elsif Whatsapp::DraftSentiment.valid_id(draft_data, projekt_phase).blank? &&
              Whatsapp::DraftSentiment.required?(projekt_phase)
          :sentiment
        end
    end

    def ask_for(requirement)
      return Whatsapp::Flows::AskDraftChoiceService.category(conversation: @conversation) if
        requirement == :category

      Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation: @conversation)
    end

    def persist
      Whatsapp::PersistDraftService.call(conversation: @conversation, draft_data: draft_data)
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
