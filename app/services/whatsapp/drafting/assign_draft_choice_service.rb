class Whatsapp::Drafting::AssignDraftChoiceService < ApplicationService
  # A category or sentiment answer written onto the draft, whichever of its two
  # states the draft is in: onto the stashed data before the record exists, because
  # the validation this satisfies runs at creation and the record cannot be written
  # until it is satisfied, and onto the record afterwards, where the citizen is
  # correcting a choice rather than supplying a missing one.
  #
  # The policy is passed in rather than chosen here: the two kinds differ in nothing
  # but which options they read, and a caller reading `call(kind: :category)` would
  # be one branch away from writing a sentiment id into a label column.
  Result = Struct.new(:resource, :missing, :errors, :rejected, keyword_init: true) do
    def rejected?
      rejected.present?
    end

    def missing?
      missing.present?
    end

    def invalid?
      errors.present?
    end
  end

  def initialize(conversation:, policy:, option_id:)
    @conversation = conversation
    @policy = policy
    @option_id = option_id
  end

  def call
    return Result.new(rejected: :not_collected) if !@policy.required?
    return Result.new(rejected: :unknown_option) if !offered?

    return assign_to_record if @conversation.draft_resource.present?
    return Result.new(rejected: :no_draft) if @conversation.draft_data.blank?

    @conversation.stash_draft_choice!(@policy.stash_for(@option_id))

    complete
  end

  private

    def offered?
      @policy.options.any? { |option| option.id.to_s == @option_id.to_s }
    end

    # Re-validated by the policy rather than trusted, because the id can arrive from
    # a pill sent days ago and the option may since have been removed from the phase.
    def assign_to_record
      return Result.new(rejected: :unknown_option) if
        !@policy.assign!(@conversation.draft_resource, @option_id)

      Result.new(resource: @conversation.draft_resource)
    end

    # The answer may have been the last thing outstanding, in which case the draft is
    # written by it — so the completion gate runs here rather than being left to the
    # caller to remember.
    def complete
      stored = ::Whatsapp::Drafting::CompleteDraftService.call(conversation: @conversation)

      Result.new(resource: stored.resource, missing: stored.missing, errors: stored.errors)
    end
end
