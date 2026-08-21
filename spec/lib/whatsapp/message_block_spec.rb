require "rails_helper"

describe Whatsapp::MessageBlock do
  let(:account) { double(:account) }

  before do
    # The identity, which is also BotCopyService's own behaviour on every failure
    # path — it answers with its input rather than leaving a label blank.
    allow(Whatsapp::AiAssistant::BotCopyService)
      .to receive(:call) { |account:, lines:| lines }
  end

  describe ".labels" do
    it "asks for every key in one call, keyed as it was asked" do
      expect(Whatsapp::AiAssistant::BotCopyService).to receive(:call).once.and_call_original

      labels = Whatsapp::MessageBlock.labels(
        account: account, scope: "whatsapp.bot.preview", keys: %w[projekt phase]
      )

      expect(labels.keys).to eq(%w[projekt phase])
      expect(labels.values).to all(be_present)
    end
  end

  describe ".compose" do
    it "separates the sections it is given" do
      expect(Whatsapp::MessageBlock.compose(["one", "two"])).to eq("one\n\ntwo")
    end

    it "drops blank sections rather than leaving a gap" do
      expect(Whatsapp::MessageBlock.compose(["one", nil, "", "two"])).to eq("one\n\ntwo")
    end

    it "is nil when nothing survives" do
      expect(Whatsapp::MessageBlock.compose([nil, ""])).to be_nil
    end
  end

  describe ".labelled_lines" do
    it "keeps the group together on single breaks" do
      expect(Whatsapp::MessageBlock.labelled_lines([["Projekt", "A"], ["Phase", "B"]]))
        .to eq("Projekt: A\nPhase: B")
    end

    it "leaves out a pair whose value is missing" do
      expect(Whatsapp::MessageBlock.labelled_lines([["Projekt", "A"], ["Angehängt", nil]]))
        .to eq("Projekt: A")
    end

    it "is nil when no pair has a value" do
      expect(Whatsapp::MessageBlock.labelled_lines([["Projekt", nil]])).to be_nil
    end
  end

  describe ".chunks" do
    it "leaves a block that fits one message alone" do
      expect(Whatsapp::MessageBlock.chunks("kurz")).to eq(["kurz"])
    end

    it "splits a longer block at paragraph boundaries without losing a character" do
      block = (1..400).map { |number| "paragraph #{number} #{"x" * 40}" }.join("\n\n")

      parts = Whatsapp::MessageBlock.chunks(block)

      expect(parts.length).to be > 1
      expect(parts.map(&:length)).to all(be <= Whatsapp::MAX_TEXT_BODY_LENGTH)
      expect(parts.join("\n\n")).to eq(block)
    end

    it "slices a single paragraph that no message could hold" do
      block = "x" * (Whatsapp::MAX_TEXT_BODY_LENGTH * 2 + 5)

      parts = Whatsapp::MessageBlock.chunks(block)

      expect(parts.map(&:length)).to all(be <= Whatsapp::MAX_TEXT_BODY_LENGTH)
      expect(parts.join).to eq(block)
    end
  end

  describe ".digest" do
    it "is stable for the same values" do
      expect(Whatsapp::MessageBlock.digest(%w[a b]))
        .to eq(Whatsapp::MessageBlock.digest(%w[a b]))
    end

    # The separator earns its place here: joined on nothing, these two would be
    # the same digest and a revision could pass for the text it replaced.
    it "tells apart values that would join into the same string" do
      expect(Whatsapp::MessageBlock.digest(%w[ab c]))
        .not_to eq(Whatsapp::MessageBlock.digest(%w[a bc]))
    end
  end

  describe ".verbatim" do
    it "does not truncate" do
      long_text = "wort " * 2_000

      expect(Whatsapp::MessageBlock.verbatim("<p>#{long_text}</p>")).to eq(long_text.squish)
    end

    # The bug this exists to prevent: strip_tags alone runs the last word of one
    # paragraph into the first word of the next.
    it "keeps a word boundary between two paragraphs" do
      expect(Whatsapp::MessageBlock.verbatim("<p>fehlen Bügel.</p><p>Zweiter Absatz</p>"))
        .to eq("fehlen Bügel.\n\nZweiter Absatz")
    end

    it "is nil for markup with no text in it" do
      expect(Whatsapp::MessageBlock.verbatim("<p></p>")).to be_nil
    end
  end
end
