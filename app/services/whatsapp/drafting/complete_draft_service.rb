class Whatsapp::Drafting::CompleteDraftService < ApplicationService
  # The gate between a generated draft and a persisted one. It exists because the
  # category and sentiment validations run only at creation: once the record is
  # written, nothing can make it valid, so everything the phase requires has to be
  # in hand first. Until then the draft lives in the conversation's context.
  #
  # Called by every tool that could have completed it — the drafting tool, the two
  # taxonomy tools, and the publish tool on its way past — so a draft is written
  # the moment it can be, whichever answer was the last one outstanding.
  Result = Struct.new(:resource, :missing, :errors, keyword_init: true) do
    def stored?
      resource.present?
    end

    def missing?
      missing.present?
    end

    def invalid?
      errors.present?
    end
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    # Nothing new to write: the citizen corrected a choice on a record that already
    # exists, and the stash was emptied when it was created. The empty stash is the
    # dirty flag — re-persisting would drop the stored evaluation verdict,
    # re-geocode the location, and re-apply the model's stale ids over the
    # correction just made.
    return Result.new(resource: @conversation.draft_resource) if draft_data.blank?

    missing = missing_requirement

    # Only before the record exists. On a revision the record is already there, so
    # the on-create validations no longer run and a choice made earlier is still on
    # it — asking again would be asking twice.
    if @conversation.draft_resource.blank? && missing.present?
      return Result.new(missing: missing.kind)
    end

    persist
  end

  private

    def draft_data
      @draft_data ||= @conversation.draft_data.to_h
    end

    def missing_requirement
      ::Whatsapp::DraftTaxonomy
        .requirements(@conversation.projekt_phase)
        .find { |requirement| !requirement.satisfied_by?(draft_data) }
    end

    # PersistDraftService saves with validations on, and the save is the last thing
    # standing between a citizen and their submission. Unrescued it escaped the
    # whole inbound job: nothing was sent, and the citizen was left with no reply at
    # all. The messages travel back instead, because they name the only thing that
    # can be changed about it.
    def persist
      resource = ::Whatsapp::Drafting::PersistDraftService.call(
        conversation: @conversation, draft_data: draft_data
      )

      @conversation.update!(draft_resource: resource)
      @conversation.clear_draft_data!

      Result.new(resource: resource)
    rescue ActiveRecord::RecordInvalid => e
      report(e)

      Result.new(errors: e.record.errors.full_messages)
    end

    def report(exception)
      Rails.logger.error(
        "[Whatsapp] draft persistence failed: #{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: @conversation.id })
    end
end
