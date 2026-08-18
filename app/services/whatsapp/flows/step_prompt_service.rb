class Whatsapp::Flows::StepPromptService < Whatsapp::Flows::BaseService
  # The question a step is waiting on, asked again. Three callers need it and
  # all three arrive from somewhere the citizen has been away: the
  # continue-or-restart answer, a parked submission resumed after a side trip,
  # and any future return path. One map rather than three, because a step
  # missing from one of them is a citizen answered with the menu and a
  # half-written submission dropped on the floor.
  #
  # Each step is re-asked through the entry point that re-asks rather than the
  # one that first arrives: AskRevisionService.re_ask leaves the origin the
  # draft card recorded alone, ProposalImageService.ask_upload asks for the
  # photo instead of re-offering the choice already made, and
  # AskLocationService.re_ask puts the pin question without spending the one
  # miss #remind would.
  #
  # Anything unmapped is the menu, which is also where a comment whose proposal
  # has since gone lands.
  def self.call(conversation:, step:)
    new(conversation: conversation, step: step).call
  end

  def initialize(conversation:, step:)
    super(conversation: conversation)
    @step = step
  end

  def call
    steps = Whatsapp::Conversation::Step

    case @step
    when steps::AWAITING_IDEA
      Whatsapp::Flows::AskIdeaService.call(conversation: @conversation)
    when steps::AWAITING_COMMENT
      comment_prompt
    when steps::AWAITING_IMAGE_UPLOAD
      Whatsapp::Flows::ProposalImageService.ask_upload(conversation: @conversation)
    when steps::AWAITING_IMAGE_CHOICE
      Whatsapp::Flows::ProposalImageService.ask(conversation: @conversation)
    when steps::AWAITING_REVISION
      Whatsapp::Flows::AskRevisionService.re_ask(conversation: @conversation)
    when steps::AWAITING_LOCATION
      Whatsapp::Flows::AskLocationService.re_ask(conversation: @conversation)
    when steps::AWAITING_PARTICIPATION_PROJEKT
      Whatsapp::Flows::ProjektParticipationService.ask_projekt(conversation: @conversation)
    when steps::AWAITING_DRAFT_DECISION
      Whatsapp::Flows::PresentDraftService.first_draft(conversation: @conversation)
    when steps::AWAITING_CATEGORY
      Whatsapp::Flows::AskDraftChoiceService.category(conversation: @conversation)
    when steps::AWAITING_SENTIMENT
      Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation: @conversation)
    when steps::AWAITING_DUPLICATE_DECISION
      Whatsapp::Flows::AskDuplicateChoiceService.reask(conversation: @conversation)
    when steps::AWAITING_NOTIFICATION_SETTINGS
      Whatsapp::Flows::NotificationSettingsService.call(conversation: @conversation)
    else
      Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation)
    end
  end

  private

    # The comment question needs the record it is about, and it can be gone by
    # now — deleted, or its projekt closed. The menu is the honest answer then:
    # asking for a comment again would invite one that nothing would accept.
    def comment_prompt
      proposal = Proposal.find_by(id: @conversation.comment_proposal_id)

      return Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation) if
        proposal.blank?

      Whatsapp::Flows::CommentService.prompt(conversation: @conversation, proposal: proposal)
    end
end
