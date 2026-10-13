require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::DraftProposal do
  # The similar contributions handed over with a draft carry the support pill the
  # proposal would get anywhere else in the chat (Whatsapp::ContributionFacts): none
  # on the citizen's own proposal, unless they supported it on the page before.
  subject(:tool) { Ai::Tools::WhatsappAiAssistant::DraftProposal.new(conversation: conversation) }

  let(:user) { double(:user, id: 1) }
  let(:account) { double(:account, user: user, terms_accepted?: true) }
  let(:projekt_phase) { double(:projekt_phase, user_resource_criteria: double(exists?: false)) }
  let(:resource) { double(:resource, title: "Trinkbrunnen am Skaterpark", description: "Ein Brunnen") }
  let(:taxonomy) { double(:taxonomy, display_name: nil) }
  let(:candidates) { [] }

  let(:conversation) do
    double(
      :conversation,
      whatsapp_account: account,
      projekt_phase: projekt_phase,
      last_draft_at: nil,
      last_screened_at: nil,
      last_idea_text: "Trinkbrunnen am Skaterpark",
      additions_beyond_idea: nil,
      image_question_available?: false,
      location_question_available?: false
    ).tap do |stub|
      allow(stub).to receive(:store_idea_text!)
      allow(stub).to receive(:stamp_screened!)
      allow(stub).to receive(:store_generated_draft!)
    end
  end

  def proposal(id:, author_id:, voted_up: false)
    instance_double(
      Proposal, id: id, title: "Vorschlag #{id}", author_id: author_id, cached_votes_up: 3, is_a?: true
    ).tap do |stub|
      allow(stub).to receive(:voted_up_by?).with(user).and_return(voted_up)
    end
  end

  def similar_contributions
    tool.execute(
      text: "Trinkbrunnen am Skaterpark", contribution_intent: "Ich schlage vor"
    )[:similar_contributions]
  end

  before do
    allow(Whatsapp::Drafting::ResourceCreationValidationService).to receive(:call).and_return(nil)
    allow(Whatsapp::Drafting::SubmissionAuthorService).to receive(:call).and_return(user)
    allow(ProposalAiDraft::EvaluateContentSafetyService).to receive(:with_search_terms)
      .and_return(double(:safety, success?: true, reason: nil, search_terms: []))
    allow(ProposalAiDraft::GenerateDraftService).to receive(:with_required_taxonomy)
      .and_return(double(:generated, to_h: {}))
    allow(Whatsapp::Drafting::CompleteDraftService).to receive(:call)
      .and_return(double(:stored, invalid?: false, missing?: false, resource: resource))
    allow(Whatsapp::DraftTaxonomy).to receive(:category).and_return(taxonomy)
    allow(Whatsapp::DraftTaxonomy).to receive(:sentiment).and_return(taxonomy)
    allow(Whatsapp::SimilarProposalsQuery).to receive(:call).and_return(candidates)
    allow(Whatsapp::PublishedResourceUrl).to receive(:call) { |record| "https://example.org/#{record.id}" }
  end

  context "with someone else's proposal" do
    let(:candidates) { [proposal(id: 12, author_id: 2)] }

    it "offers the support pill" do
      expect(similar_contributions.first).to include(
        written_by_you: false, action_id: "support_toggle-12"
      )
    end
  end

  context "with the citizen's own proposal" do
    let(:candidates) { [proposal(id: 12, author_id: 1)] }

    it "marks it as theirs and offers no support for it" do
      expect(similar_contributions.first).to include(written_by_you: true)
      expect(similar_contributions.first).not_to have_key(:action_id)
    end
  end

  context "with the citizen's own proposal they supported on the page" do
    let(:candidates) { [proposal(id: 12, author_id: 1, voted_up: true)] }

    it "keeps the pill that takes the support back" do
      expect(similar_contributions.first).to include(
        written_by_you: true, action_id: "support_toggle-12"
      )
    end
  end
end
