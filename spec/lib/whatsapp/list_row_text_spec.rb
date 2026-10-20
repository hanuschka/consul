require "rails_helper"

describe Whatsapp::ListRowText do
  let(:omission) { Whatsapp::AssistantActions::TRUNCATION_OMISSION }

  describe ".call" do
    it "keeps a name that fits the title whole, with the notes underneath" do
      lines = Whatsapp::ListRowText.call(name: "Kurz", notes: ["Ideen", "31. Dezember 2026"])

      expect(lines).to eq(title: "Kurz", description: "Ideen · 31. Dezember 2026")
    end

    it "leaves the line underneath empty where there is nothing to put there" do
      expect(Whatsapp::ListRowText.call(name: "Kurz")).to eq(title: "Kurz", description: nil)
    end

    it "drops blank notes rather than leaving a separator behind" do
      lines = Whatsapp::ListRowText.call(name: "Kurz", notes: [nil, "", "Ideen"])

      expect(lines[:description]).to eq("Ideen")
    end

    it "is nil for a blank name" do
      expect(Whatsapp::ListRowText.call(name: "  ", notes: ["Ideen"])).to be_nil
    end

    it "splits a long name at a word boundary and carries it on ahead of the notes" do
      lines = Whatsapp::ListRowText.call(
        name: "WhatsApp-Test: Grundfragen zur Mobilität",
        notes: ["Bereits abgestimmt", "31. Dezember 2026"]
      )

      expect(lines).to eq(
        title: "WhatsApp-Test:#{omission}",
        description: "Grundfragen zur Mobilität · Bereits abgestimmt · 31. Dezember 2026"
      )
    end

    it "tells apart two names that differ only past the title" do
      notes = ["Bereits abgestimmt", "31. Dezember 2026"]
      first = Whatsapp::ListRowText.call(
        name: "WhatsApp-Test: Grundfragen zur Mobilität", notes: notes
      )
      second = Whatsapp::ListRowText.call(
        name: "WhatsApp-Test: Grundfragen zur Innenstadt", notes: notes
      )

      expect(first[:title]).to eq(second[:title])
      expect(first[:description]).not_to eq(second[:description])
    end

    it "cuts a name with no boundary worth splitting at and repeats it whole underneath" do
      name = "Benachrichtigungseinstellungen ändern"
      lines = Whatsapp::ListRowText.call(name: name, notes: ["Profil"])

      expect(lines[:title].length).to eq(Whatsapp::AssistantActions::MAX_ROW_TITLE_LENGTH)
      expect(lines[:title]).to start_with("Benachrichtigungs").and end_with(omission)
      expect(lines[:description]).to eq("#{name} · Profil")
    end

    it "keeps room for the rest of the name however long the notes are" do
      lines = Whatsapp::ListRowText.call(
        name: "WhatsApp-Test: Grundfragen zur Mobilität in der Innenstadt",
        notes: ["a" * 60]
      )

      rest = lines[:description].split(Whatsapp::ListRowText::NOTE_SEPARATOR).first

      expect(rest).to start_with("Grundfragen zur Mobilit")
      expect(rest.length).to eq(Whatsapp::ListRowText::MIN_REST_LENGTH)
    end

    it "never lets the line underneath outgrow what a row shows" do
      lines = Whatsapp::ListRowText.call(
        name: "WhatsApp-Test: #{"Grundfragen " * 10}", notes: ["b" * 60]
      )

      expect(lines[:description].length).to be <= Whatsapp::MAX_ROW_DESCRIPTION_LENGTH
    end
  end
end
