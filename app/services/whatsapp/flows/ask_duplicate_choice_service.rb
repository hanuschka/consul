class Whatsapp::Flows::AskDuplicateChoiceService < Whatsapp::Flows::BaseService
  # Whether the portal already holds the proposal the citizen is about to
  # write, asked before the draft is generated. Supporting one that exists is
  # worth more to them and to the projekt than a second copy of it, and
  # afterwards is too late: nothing merges two published proposals from a chat.
  #
  # Returns true when the citizen was asked and false when nothing similar
  # turned up, which is the caller's signal to carry on drafting untouched.
  #
  # Asked for the first time, off the text the citizen just sent.
  #
  # The search runs on their words and on the words a duplicate might have been
  # written with instead: matching tokens alone, "Zebrastreifen" and
  # "Fußgängerüberweg" are two unrelated proposals, and the ranking call below
  # can only judge what the search hands it. The widening terms arrive from the
  # caller, where the screening call already produced them, rather than being
  # asked for a second time here — and the ranking call brings each kept
  # proposal's row line back with the verdict, so the offer never pays a
  # summary call per row.
  def self.for_idea(conversation:, idea_text:, search_terms: [])
    candidates = Whatsapp::SimilarProposalsQuery.call(
      projekt_phase: conversation.projekt_phase,
      text: idea_text,
      extra_terms: search_terms
    )

    ranked = Whatsapp::AiAssistant::SimilarProposalsRankService.call(
      idea_text: idea_text, proposals: candidates
    )

    new(
      conversation: conversation,
      similar_proposals: ranked.proposals,
      row_descriptions: ranked.row_descriptions
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
      similar_proposals: ids.filter_map { |id| proposals_by_id[id] },
      row_descriptions: conversation.context["duplicate_row_descriptions"].to_h
    ).call
  end

  # A stale step with nothing left to offer — every proposal retired, the
  # context purged — asks for the idea again rather than leaving the citizen
  # on a question that can no longer be put.
  def self.handle_answer(conversation:)
    return if reask(conversation: conversation)

    Whatsapp::Flows::AskIdeaService.call(conversation: conversation)
  end

  # The "submit anyway" pill. The idea was screened on the way in, so it goes
  # straight to generation. Nothing to draft from means the context was purged
  # between the offer and the tap; asking again is the only way forward.
  def self.submit_anyway(conversation:, inbound_message_id: nil)
    if conversation.context["last_idea_text"].blank?
      return Whatsapp::Flows::AskIdeaService.call(conversation: conversation)
    end

    Whatsapp::Flows::BuildDraftService.from_accepted_idea(
      conversation: conversation, inbound_message_id: inbound_message_id
    )
  end

  # The duplicate offer's own support pill: the citizen chose an existing
  # proposal over writing their own, so the submission it interrupted is over
  # and the menu is what follows publishing too.
  def self.support_instead(conversation:, proposal_id:)
    registered = Whatsapp::Flows::SupportService.register(
      conversation: conversation, proposal_id: proposal_id
    )

    # Only once the support actually landed. A proposal retired between the
    # offer and the tap answers "that one is gone" — ending the flow there
    # would throw away the idea they were part-way through submitting, and
    # they would have to type the whole thing again.
    return if !registered

    Whatsapp::Flows::MainMenuService.greeting(conversation: conversation)
  end

  def initialize(conversation:, similar_proposals:, row_descriptions: {})
    super(conversation: conversation)
    @similar_proposals = similar_proposals
    @row_descriptions = row_descriptions.to_h
  end

  # The row lines are stored beside the ids for the same reason the ids are:
  # a stray message re-asks the question from context, and the ranking call
  # that wrote the lines has already happened.
  def call
    return false if similar_proposals.blank?

    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_DUPLICATE_DECISION)
    @conversation.merge_context!(
      duplicate_proposal_ids: similar_proposals.map(&:id),
      duplicate_row_descriptions: @row_descriptions
    )

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
        body: Whatsapp.phrase("whatsapp.bot.proposal.duplicate.single", title: proposal.title,
          url: Whatsapp::PublishedResourceUrl.call(proposal)),
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
        body: Whatsapp.phrase("whatsapp.bot.proposal.duplicate.multiple"),
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
          description: row_description_for(proposal)
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

    # Written by the ranking call, which had just read the proposal to judge
    # it. The truncation fallback covers a row the model left blank and a
    # conversation whose offer predates the stored lines — the ragged edge
    # every row had before the lines existed, never an extra completion.
    def row_description_for(proposal)
      @row_descriptions[proposal.id.to_s].presence ||
        ::Whatsapp.plain_text(
          proposal.description,
          length: Whatsapp::AiAssistant::SimilarProposalsRankService::ROW_DESCRIPTION_LENGTH
        )
    end
end
