class Whatsapp::Flows::CompleteDraftService < Whatsapp::Flows::BaseService
  # The gate between a generated draft and a persisted one, and the single place
  # that decides whether the citizen still has to answer something.
  #
  # It exists because the label and sentiment validations run only at creation:
  # once the record is written, nothing can make it valid, so everything they
  # need has to be in hand first. Until then the draft lives in the
  # conversation's context and this service asks for what is missing.
  #
  # A missing choice is rare by construction: the drafting schema forces a
  # valid pick wherever the provider enforces schemas, so the question below
  # covers only what a schema cannot force — a non-strict provider's stray
  # answer, or an option removed from the phase between the two calls.
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
    missing = missing_requirement

    return ask_for(missing) if ask_before_creating?(missing)

    # Nothing new to write: the citizen corrected a choice on a record that
    # already exists, and the stash was emptied when it was created. The empty
    # stash is the dirty flag — re-persisting here would drop the stored
    # evaluation verdict, re-geocode the location, and re-apply the model's
    # stale ids over the correction the citizen just made.
    return present if draft_data.blank?

    @conversation.update!(draft_resource: persist)
    @conversation.clear_draft_data!

    present
  end

  private

    def draft_data
      @draft_data ||= @conversation.draft_data.to_h
    end

    # Only before the record exists. On a revision the record is already there,
    # so the on-create validations no longer run and a choice the citizen made
    # earlier is still on it — asking again would be asking twice.
    def ask_before_creating?(missing)
      @conversation.draft_resource.blank? && missing.present?
    end

    # What the resource's on-create validations demand and the drafting model
    # did not supply. Asked of the draft data rather than of a record, because
    # those validations run exactly once — at the first save — so there is no
    # record yet to ask.
    def missing_requirement
      Whatsapp::DraftTaxonomy
        .requirements(@conversation.projekt_phase)
        .find { |requirement| !requirement.satisfied_by?(draft_data) }
    end

    def ask_for(requirement)
      return Whatsapp::Flows::AskDraftChoiceService.category(conversation: @conversation) if
        requirement.kind == :category

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
