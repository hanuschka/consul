require "rails_helper"

describe Whatsapp::DraftPreview do
  # Doubles rather than records throughout: what is under test is the composition,
  # and the one property that matters — that the citizen's own title and text come
  # through untouched — is easier to assert against text nobody generated.
  let(:projekt) { double(:projekt) }
  let(:projekt_phase) { double(:projekt_phase, id: 7, projekt: projekt, title: "Vorschläge") }
  let(:account) { double(:account) }

  let(:title) { "Fahrradbügel am Bahnhof" }
  let(:description) { "<p>Am Bahnhof fehlen Bügel.</p>" }

  let(:resource) do
    double(:resource, title: title, description: description, image: nil, map_location: nil)
  end

  let(:conversation) do
    double(
      :conversation,
      draft_resource: resource,
      projekt_phase: projekt_phase,
      projekt_phase_id: projekt_phase.id,
      whatsapp_account: account
    )
  end

  before do
    allow(Whatsapp::ProjektLink).to receive(:title).with(projekt).and_return("Teststudio 2")

    # The translation is the identity here, which is also its behaviour whenever the
    # provider is unavailable — BotCopyService answers with its own input.
    allow(Whatsapp::AiAssistant::BotCopyService)
      .to receive(:call) { |account:, lines:| lines }
  end

  describe ".confirmation_block" do
    it "carries the title and the text exactly as the record holds them" do
      block = Whatsapp::DraftPreview.confirmation_block(conversation: conversation)

      expect(block).to include("*#{title}*")
      expect(block).to include("Am Bahnhof fehlen Bügel.")
    end

    it "names the projekt and the participation phase it goes into" do
      block = Whatsapp::DraftPreview.confirmation_block(conversation: conversation)

      expect(block).to include("Teststudio 2")
      expect(block).to include("Vorschläge")
    end

    it "does not truncate a description longer than any message holds" do
      long_text = "wort " * 2_000

      allow(resource).to receive(:description).and_return("<p>#{long_text}</p>")

      block = Whatsapp::DraftPreview.confirmation_block(conversation: conversation)

      expect(block).to include(long_text.squish)
    end

    it "names no attachment when the draft carries none" do
      expect(Whatsapp::DraftPreview.confirmation_block(conversation: conversation))
        .not_to include("Angehängt")
    end

    it "names a photo the citizen never typed" do
      attach_image(blob_id: 42)

      expect(Whatsapp::DraftPreview.confirmation_block(conversation: conversation))
        .to include("Angehängt", "Foto")
    end

    it "names a pin the citizen never typed" do
      attach_pin(latitude: 51.5, longitude: 7.2)

      expect(Whatsapp::DraftPreview.confirmation_block(conversation: conversation))
        .to include("Angehängt", "Standort")
    end

    it "is nil when there is no draft to show" do
      allow(conversation).to receive(:draft_resource).and_return(nil)

      expect(Whatsapp::DraftPreview.confirmation_block(conversation: conversation)).to be_nil
    end
  end

  describe ".published_block" do
    it "repeats the contribution and writes the address out" do
      block = Whatsapp::DraftPreview.published_block(
        conversation: conversation, url: "https://example.org/proposals/1"
      )

      expect(block).to include("*#{title}*")
      expect(block).to include("https://example.org/proposals/1")
    end
  end

  describe ".awaiting_review_block" do
    it "repeats the contribution and offers no address at all" do
      block = Whatsapp::DraftPreview.awaiting_review_block(conversation: conversation)

      expect(block).to include("*#{title}*")
      expect(block).not_to include("http")
    end
  end

  describe ".digest" do
    it "is stable for an unchanged draft" do
      expect(Whatsapp::DraftPreview.digest(conversation: conversation))
        .to eq(Whatsapp::DraftPreview.digest(conversation: conversation))
    end

    it "changes when the title changes" do
      before_revision = Whatsapp::DraftPreview.digest(conversation: conversation)

      allow(resource).to receive(:title).and_return("Fahrradbügel am Hauptbahnhof")

      expect(Whatsapp::DraftPreview.digest(conversation: conversation)).not_to eq(before_revision)
    end

    it "changes when the text changes" do
      before_revision = Whatsapp::DraftPreview.digest(conversation: conversation)

      allow(resource).to receive(:description).and_return("<p>Am Hauptbahnhof fehlen Bügel.</p>")

      expect(Whatsapp::DraftPreview.digest(conversation: conversation)).not_to eq(before_revision)
    end

    it "changes when a photo is attached" do
      before_attachment = Whatsapp::DraftPreview.digest(conversation: conversation)

      attach_image(blob_id: 42)

      expect(Whatsapp::DraftPreview.digest(conversation: conversation)).not_to eq(before_attachment)
    end

    it "changes when a pin is attached" do
      before_attachment = Whatsapp::DraftPreview.digest(conversation: conversation)

      attach_pin(latitude: 51.5, longitude: 7.2)

      expect(Whatsapp::DraftPreview.digest(conversation: conversation)).not_to eq(before_attachment)
    end

    it "is nil when there is no draft" do
      allow(conversation).to receive(:draft_resource).and_return(nil)

      expect(Whatsapp::DraftPreview.digest(conversation: conversation)).to be_nil
    end
  end

  def attach_image(blob_id:)
    blob = double(:blob, id: blob_id)
    attachment = double(:attachment, blob: blob)

    allow(resource).to receive(:image).and_return(double(:image, attachment: attachment))
  end

  def attach_pin(latitude:, longitude:)
    allow(resource)
      .to receive(:map_location)
      .and_return(double(:map_location, latitude: latitude, longitude: longitude))
  end
end
