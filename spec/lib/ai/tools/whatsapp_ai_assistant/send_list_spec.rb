require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::SendList do
  subject(:tool) { Ai::Tools::WhatsappAiAssistant::SendList.new(conversation: conversation) }

  let(:account) { double(:account) }
  let(:conversation) do
    double(:conversation, whatsapp_account: account, unshown_preview_kind: nil, step: nil)
  end
  let(:omission) { Whatsapp::AssistantActions::TRUNCATION_OMISSION }

  let(:alike_ballots) do
    [
      {
        "action_id" => "phase_open-11",
        "label" => "WhatsApp-Test: Grundfragen zur Mobilität",
        "description" => "31. Dezember 2026"
      },
      {
        "action_id" => "phase_open-12",
        "label" => "WhatsApp-Test: Grundfragen zur Innenstadt",
        "description" => "31. Dezember 2026"
      }
    ]
  end

  def sent_rows
    sent = nil

    expect(Whatsapp::Send).to have_received(:list) { |**arguments| sent = arguments[:rows] }

    sent
  end

  before do
    allow(Whatsapp::AssistantActions)
      .to receive(:with_records_preloaded) { |*, **, &block| block.call }
    # The row the real one builds for a label the model wrote: the id, and the
    # label as far as the asked-for length.
    allow(Whatsapp::AssistantActions).to receive(:offered_row) do |spec:, label:, length:, **|
      { id: "row_#{spec}", title: label.truncate(length) }
    end
    allow(Whatsapp::AssistantActions).to receive(:row_description).and_return(nil)
    allow(Whatsapp::AssistantActions).to receive(:list_opener).and_return("Auswählen")
    allow(Whatsapp::FlowActions).to receive(:projekt_choice?).and_return(false)
    allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record)
    allow(Whatsapp::Send).to receive(:list).and_return(double(:message, status: "sent"))
  end

  it "splits a label too long for the title over the row's two lines" do
    tool.execute(body: "Welche Abstimmung?", rows: alike_ballots)

    expect(sent_rows).to eq(
      [
        {
          id: "row_phase_open-11",
          title: "WhatsApp-Test:#{omission}",
          description: "Grundfragen zur Mobilität · 31. Dezember 2026"
        },
        {
          id: "row_phase_open-12",
          title: "WhatsApp-Test:#{omission}",
          description: "Grundfragen zur Innenstadt · 31. Dezember 2026"
        }
      ]
    )
  end

  it "asks for the name whole rather than cut to the title" do
    tool.execute(body: "Welche Abstimmung?", rows: alike_ballots)

    expect(Whatsapp::AssistantActions).to have_received(:offered_row)
      .with(hash_including(length: Ai::Tools::WhatsappAiAssistant::SendList::MAX_NAME_LENGTH))
      .twice
  end

  it "keeps a label that fits the title as it is" do
    tool.execute(
      body: "Was möchtest du tun?",
      rows: [{ "action_id" => "phase_open-11", "label" => "Kurz", "description" => "Ideen" }]
    )

    expect(sent_rows).to eq([{ id: "row_phase_open-11", title: "Kurz", description: "Ideen" }])
  end

  it "leaves a short row without a description as a title alone" do
    tool.execute(
      body: "Was möchtest du tun?", rows: [{ "action_id" => "phase_open-11", "label" => "Kurz" }]
    )

    expect(sent_rows).to eq([{ id: "row_phase_open-11", title: "Kurz" }])
  end

  it "does not tell the model its words were changed where they were only split" do
    result = tool.execute(body: "Welche Abstimmung?", rows: alike_ballots)

    expect(result.content).to start_with("Sent a list of 2 rows")
    expect(result.content).not_to include("do not carry the words you wrote")
  end

  it "still refuses a label longer than a split row can show" do
    label = "a" * (Ai::Tools::WhatsappAiAssistant::SendList::MAX_NAME_LENGTH + 1)

    result = tool.execute(
      body: "Welche Abstimmung?", rows: [{ "action_id" => "phase_open-11", "label" => label }]
    )

    expect(result[:error]).to include("longer than the 96 characters")
    expect(Whatsapp::Send).not_to have_received(:list)
  end
end
