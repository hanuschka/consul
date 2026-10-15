require "rails_helper"

describe Whatsapp::ProjektCardActions do
  def entry(id, title, button_title: title)
    { id: id, title: title, description: "Ideen", **{ button_title: button_title }.compact }
  end

  describe ".buttons" do
    let(:small_card) do
      [
        entry("idea_start-1", "Vorschlag erstellen"),
        entry("phase_open-2", "Mangel melden"),
        entry("phase_contributions-1", "Beiträge ansehen")
      ]
    end

    it "sends a card of three entries as buttons, without the line underneath" do
      expect(Whatsapp::ProjektCardActions.buttons(small_card)).to eq(
        [
          { id: "idea_start-1", title: "Vorschlag erstellen" },
          { id: "phase_open-2", title: "Mangel melden" },
          { id: "phase_contributions-1", title: "Beiträge ansehen" }
        ]
      )
    end

    it "sends the card cut down to the way to submit as a button" do
      buttons = Whatsapp::ProjektCardActions.buttons([entry("idea_start-1", "Vorschlag erstellen")])

      expect(buttons).to eq([{ id: "idea_start-1", title: "Vorschlag erstellen" }])
    end

    it "keeps a card with more entries than buttons fit a list" do
      card = small_card + [entry("phase_open-3", "Jetzt abstimmen")]

      expect(Whatsapp::ProjektCardActions.buttons(card)).to be_nil
    end

    it "keeps the card a list where a title would have to be cut to fit a button" do
      card = [
        entry("idea_start-1", "Vorschlag erstellen"),
        entry("phase_open-3", "✓ WhatsApp-Test:…", button_title: nil)
      ]

      expect(Whatsapp::ProjektCardActions.buttons(card)).to be_nil
    end

    it "keeps the card a list where two titles read alike" do
      card = [entry("phase_open-3", "Jetzt abstimmen"), entry("phase_open-4", "Jetzt abstimmen")]

      expect(Whatsapp::ProjektCardActions.buttons(card)).to be_nil
    end
  end

  describe ".button_title" do
    it "is the title where a button holds it whole" do
      expect(Whatsapp::ProjektCardActions.button_title(" Jetzt  abstimmen ")).to eq("Jetzt abstimmen")
    end

    it "is nil where a button would have to cut the title" do
      expect(Whatsapp::ProjektCardActions.button_title("✓ WhatsApp-Test: Kartenpunkt")).to be_nil
    end

    it "is nil for a blank title" do
      expect(Whatsapp::ProjektCardActions.button_title("")).to be_nil
    end
  end

  describe ".row_lines" do
    let(:phase_facts) { double(:phase_facts, ends_on: nil) }

    it "carries the title whole beside the row's two lines" do
      row = Whatsapp::ProjektCardActions::RowText.new(
        title: "Jetzt abstimmen", note: "Haushalt", named: false
      )

      expect(Whatsapp::ProjektCardActions.row_lines(row, phase_facts)).to eq(
        title: "Jetzt abstimmen", description: "Haushalt", button_title: "Jetzt abstimmen"
      )
    end

    it "has no button title for a name a button would cut" do
      row = Whatsapp::ProjektCardActions::RowText.new(
        title: "WhatsApp-Test: Grundfragen zur Mobilität", note: "Bereits abgestimmt", named: true
      )

      lines = Whatsapp::ProjektCardActions.row_lines(row, phase_facts)

      expect(lines[:description]).to eq("Grundfragen zur Mobilität · Bereits abgestimmt")
      expect(lines[:button_title]).to be_nil
    end
  end
end
