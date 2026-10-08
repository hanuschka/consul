require "rails_helper"

describe Whatsapp::StatePills do
  # The pills a reply about one proposal or projekt carries whatever the model
  # offered, read off the state: the support pill's direction off the vote, the
  # comment pill off whether a comment would be taken, the follow pill off the
  # subscription.
  let(:user) { double(:user, id: 1) }
  let(:conversation) { double(:conversation, user: user, comment_invited?: false) }

  around { |example| I18n.with_locale(:de) { example.run } }

  after { Current.reset }

  def pill(action, param, title)
    { id: Whatsapp::FlowActions.id_for(action: action, param: param), title: title }
  end

  it "offers nothing while the turn is about nothing in particular" do
    expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq([])
  end

  describe "for a proposal" do
    let(:proposal) { double(:proposal, id: 482, author_id: 2) }
    let(:supported) { false }
    let(:comment_refusal) { nil }

    before do
      allow(Proposal).to receive_message_chain(:not_retired, :find_by)
        .with(id: 482).and_return(proposal)
      allow(proposal).to receive(:voted_up_by?).with(user).and_return(supported)
      allow(Whatsapp::AssistantActions).to receive(:supportable?).with(proposal).and_return(true)
      allow(Whatsapp::Contributions::CreateCommentService)
        .to receive(:thread_refusal).with(proposal: proposal, user: user)
        .and_return(comment_refusal)

      Whatsapp::StatePills.focus_proposal(482)
    end

    it "comes with Jetzt unterstützen and Kommentieren where the citizen has not supported it" do
      expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
        [
          pill(:support_register, 482, "Jetzt unterstützen"),
          pill(:comment_start, 482, "Kommentieren")
        ]
      )
    end

    describe "that the citizen supports" do
      let(:supported) { true }

      it "comes with Zurücknehmen and Kommentieren" do
        expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
          [
            pill(:support_withdraw, 482, "Zurücknehmen"),
            pill(:comment_start, 482, "Kommentieren")
          ]
        )
      end
    end

    describe "whose comments are closed" do
      let(:comment_refusal) { :closed }

      it "leaves out Kommentieren" do
        expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
          [pill(:support_register, 482, "Jetzt unterstützen")]
        )
      end
    end

    it "leaves out the support pill where it can no longer be supported" do
      allow(Whatsapp::AssistantActions).to receive(:supportable?).with(proposal).and_return(false)

      expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
        [pill(:comment_start, 482, "Kommentieren")]
      )
    end

    describe "that the citizen wrote" do
      let(:proposal) { double(:proposal, id: 482, author_id: 1) }

      it "leaves out Jetzt unterstützen" do
        expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
          [pill(:comment_start, 482, "Kommentieren")]
        )
      end

      describe "and supported on the page before" do
        let(:supported) { true }

        it "keeps Zurücknehmen" do
          expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
            [
              pill(:support_withdraw, 482, "Zurücknehmen"),
              pill(:comment_start, 482, "Kommentieren")
            ]
          )
        end
      end
    end

    it "offers nothing while the citizen has been asked to write their comment" do
      allow(conversation).to receive(:comment_invited?).and_return(true)

      expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq([])
    end

    it "offers nothing for a proposal that is gone" do
      allow(Proposal).to receive_message_chain(:not_retired, :find_by).and_return(nil)

      expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq([])
    end
  end

  describe "for a projekt" do
    let(:projekt) { double(:projekt, id: 45) }
    let(:following) { false }

    before do
      allow(Projekt).to receive_message_chain(:activated, :find_by)
        .with(id: 45).and_return(projekt)
      allow(Whatsapp::Subscriptions)
        .to receive(:following?).with(user: user, projekt: projekt).and_return(following)

      Whatsapp::StatePills.focus_projekt(45)
    end

    it "comes with Folgen where the citizen does not follow it" do
      expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
        [pill(:follow_enable, 45, "Folgen")]
      )
    end

    describe "that the citizen follows" do
      let(:following) { true }

      it "comes with Nicht mehr folgen" do
        expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
          [pill(:follow_disable, 45, "Nicht mehr folgen")]
        )
      end
    end

    describe "with an unlinked number" do
      let(:user) { nil }

      it "offers nothing, since following needs an account" do
        expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq([])
      end
    end
  end

  describe "after a submission" do
    before { Whatsapp::StatePills.focus_submission_completed }

    it "comes with another idea, the citizen's own contributions and the projekts" do
      expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
        [
          pill(:submit_proposal, nil, "Vorschlag erstellen"),
          pill(:my_contributions, nil, "Meine Beiträge"),
          pill(:discover, nil, "Projekte ansehen")
        ]
      )
    end
  end

  it "follows the last thing the turn surfaced" do
    projekt = double(:projekt, id: 45)

    allow(Projekt).to receive_message_chain(:activated, :find_by).and_return(projekt)
    allow(Whatsapp::Subscriptions).to receive(:following?).and_return(false)

    Whatsapp::StatePills.focus_proposal(482)
    Whatsapp::StatePills.focus_projekt(45)

    expect(Whatsapp::StatePills.buttons(conversation: conversation)).to eq(
      [pill(:follow_enable, 45, "Folgen")]
    )
  end
end
