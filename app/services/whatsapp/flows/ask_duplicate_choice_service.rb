class Whatsapp::Flows::AskDuplicateChoiceService < Whatsapp::Flows::BaseService
  # Whether the portal already holds the proposal the citizen is about to
  # write, asked before the draft is generated. Supporting one that exists is
  # worth more to them and to the projekt than a second copy of it, and
  # afterwards is too late: nothing merges two published proposals from a chat.
  #
  # Returns true when the citizen was asked and false when nothing similar
  # turned up, which is the caller's signal to carry on drafting untouched.
  ROW_DESCRIPTION_LENGTH = 72

  # Asked for the first time, off the text the citizen just sent.
  def self.for_idea(conversation:, idea_text:)
    candidates = Whatsapp::SimilarProposalsQuery.call(
      projekt_phase: conversation.projekt_phase, text: idea_text
    )

    new(
      conversation: conversation,
      similar_proposals: Whatsapp::AiAssistant::SimilarProposalsRankService.call(
        idea_text: idea_text, proposals: candidates
      )
    ).call
  end

  # Asked again because they wrote something instead of tapping. Rebuilt from
  # the ids the first asking stored: the search and the ranking call have
  # already happened, and a stray message is not a reason to pay for them twice.
  # A proposal retired in between simply drops out of the offer.
  #
  # Read back in the stored order rather than the database's, so the closest
  # match stays the first row it was the first time. The ids cannot outlive
  # their phase: every entry into a submission clears the whole context.
  def self.reask(conversation:)
    ids = conversation.context["duplicate_proposal_ids"].to_a.map(&:to_i)
    proposals_by_id = ::Proposal
      .base_selection
      .includes(:translations)
      .where(id: ids)
      .index_by(&:id)

    new(
      conversation: conversation,
      similar_proposals: ids.filter_map { |id| proposals_by_id[id] }
    ).call
  end

  def initialize(conversation:, similar_proposals:)
    super(conversation: conversation)
    @similar_proposals = similar_proposals
  end

  def call
    return false if similar_proposals.blank?

    @conversation.update!(step: "awaiting_duplicate_decision")
    @conversation.merge_context!(duplicate_proposal_ids: similar_proposals.map(&:id))

    return ask_about_one if similar_proposals.one?

    ask_about_several
  end

  private

    attr_reader :similar_proposals

    # One match is a question with three answers, which is exactly WhatsApp's
    # button budget. The link goes in the body rather than on a card of its own:
    # a second message here would push the buttons out of sight.
    def ask_about_one
      proposal = similar_proposals.first

      Whatsapp::Outbound.buttons(
        account: account,
        body: I18n.t(
          "whatsapp.bot.proposal.duplicate.single",
          title: proposal.title,
          url: Whatsapp::PublishedResourceUrl.call(proposal)
        ),
        buttons: [
          support_button(proposal),
          Whatsapp::FlowActions.button(
            action: :submit_anyway, label_key: "whatsapp.bot.buttons.submit_anyway"
          ),
          Whatsapp::Outbound.recovery_button(:cancel)
        ]
      )

      true
    end

    # Several become a list, because three proposals plus the two ways out is
    # past what buttons hold. The ways out are rows of their own for the same
    # reason: a list carries no buttons beside it, so an escape that is not a
    # row is an escape the citizen has to know to type.
    def ask_about_several
      Whatsapp::Outbound.list(
        account: account,
        body: I18n.t("whatsapp.bot.proposal.duplicate.multiple"),
        button_label: I18n.t("whatsapp.bot.proposal.duplicate.list_label"),
        rows: proposal_rows + escape_rows
      )

      true
    end

    def proposal_rows
      similar_proposals.map do |proposal|
        {
          id: Whatsapp::FlowActions.id_for(action: :support_instead, param: proposal.id),
          title: proposal.title,
          description: plain_description(proposal)
        }
      end
    end

    def escape_rows
      [
        {
          id: Whatsapp::FlowActions.id_for(action: :submit_anyway),
          title: I18n.t("whatsapp.bot.buttons.submit_anyway"),
          description: I18n.t("whatsapp.bot.proposal.duplicate.submit_anyway_hint")
        },
        Whatsapp::Outbound.recovery_button(:cancel)
      ]
    end

    def support_button(proposal)
      Whatsapp::FlowActions.button(
        action: :support_instead, label_key: "whatsapp.bot.buttons.support", param: proposal.id
      )
    end

    def plain_description(proposal)
      ::Whatsapp.plain_text(proposal.description, length: ROW_DESCRIPTION_LENGTH)
    end
end
