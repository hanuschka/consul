require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::ReplyWithActions do
  # What the model offers and what the state of the turn's proposal or projekt
  # calls for go out on one message: the state pills first, the model's own in the
  # slots that are left.
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::ReplyWithActions.new(conversation: conversation)
  end

  let(:account) { double(:account, user: double(:user)) }
  let(:conversation) do
    double(
      :conversation,
      whatsapp_account: account,
      unshown_preview_kind: nil,
      step: nil,
      submission_completed?: false
    )
  end
  let(:state_pills) { [] }

  def sent_buttons
    sent = nil

    expect(Whatsapp::Send).to have_received(:buttons) { |**arguments| sent = arguments[:buttons] }

    sent
  end

  def model_button(action_id, label)
    { "action_id" => action_id, "label" => label }
  end

  before do
    allow(Whatsapp::AssistantActions)
      .to receive(:with_records_preloaded) { |*, **, &block| block.call }
    allow(Whatsapp::AssistantActions).to receive(:offered_button) do |spec:, label:, **|
      { id: "whatsapp_flow_#{spec}", title: label }
    end
    allow(Whatsapp::StatePills).to receive(:buttons).with(conversation: conversation)
      .and_return(state_pills)
    allow(Whatsapp::FlowActions).to receive(:projekt_choice?).and_return(false)
    allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record)
    allow(Whatsapp::Send).to receive(:buttons).and_return(double(:message, status: "sent"))
  end

  it "sends the model's buttons where the turn is about nothing in particular" do
    tool.execute(body: "Was möchten Sie tun?", buttons: [model_button("my_contributions", "Meine")])

    expect(sent_buttons).to eq([{ id: "whatsapp_flow_my_contributions", title: "Meine" }])
  end

  describe "about a proposal" do
    let(:state_pills) do
      [
        { id: "whatsapp_flow_support_withdraw-482", title: "Zurücknehmen" },
        { id: "whatsapp_flow_comment_start-482", title: "Kommentieren" }
      ]
    end

    it "puts the state pills first even where the model offered none of them" do
      tool.execute(
        body: "Sie unterstützen diesen Vorschlag bereits.",
        buttons: [model_button("my_contributions", "Meine Beiträge")]
      )

      expect(sent_buttons).to eq(
        state_pills + [{ id: "whatsapp_flow_my_contributions", title: "Meine Beiträge" }]
      )
    end

    it "keeps the state pills when the model offered three buttons of its own" do
      tool.execute(
        body: "Wie geht es weiter?",
        buttons: [
          model_button("my_contributions", "Meine Beiträge"),
          model_button("discover", "Projekte"),
          model_button("submit_proposal", "Idee")
        ]
      )

      expect(sent_buttons).to eq(
        state_pills + [{ id: "whatsapp_flow_my_contributions", title: "Meine Beiträge" }]
      )
    end

    it "sends a pill the model offered as well only once" do
      allow(Whatsapp::AssistantActions).to receive(:offered_button)
        .with(spec: "support_toggle-482", label: "Zurück", conversation: conversation)
        .and_return({ id: "whatsapp_flow_support_withdraw-482", title: "Zurücknehmen" })

      tool.execute(body: "Erledigt.", buttons: [model_button("support_toggle-482", "Zurück")])

      expect(sent_buttons).to eq(state_pills)
    end

    it "names the state pills to the model among what was sent" do
      result = tool.execute(body: "Erledigt.", buttons: [])

      expect(result.content).to include(
        "whatsapp_flow_support_withdraw-482", "whatsapp_flow_comment_start-482"
      )
    end
  end
end
