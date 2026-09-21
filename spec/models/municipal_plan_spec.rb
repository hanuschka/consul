require "rails_helper"

describe MunicipalPlan do
  let(:officer) { create(:municipal_plan_officer) }

  describe "Aktualisierungsdatum and Versionsnummer" do
    let(:plan) { create(:municipal_plan, responsible: officer) }

    it "starts a draft at 0.1 and stamps today" do
      expect(plan.version).to eq("0.1")
      expect(plan.content_updated_at).to eq(Date.current)
    end

    it "counts draft edits upwards within the 0 series" do
      plan.update!(contact_name: "Kai Ostermann")

      expect(plan.reload.version).to eq("0.2")
    end

    it "moves to 1.0 on the first publication" do
      expect { plan.update!(status: "published") }
        .to change { plan.reload.version }.from("0.1").to("1.0")
    end

    it "does not advance Aktualisierungsdatum on publication" do
      plan.update_columns(content_updated_at: Date.current - 10.days)

      expect { plan.update!(status: "published") }
        .not_to change { plan.reload.content_updated_at }
    end

    it "never returns to the 0 series once published" do
      plan.update!(status: "published")
      plan.update!(contact_name: "Kai Ostermann")
      plan.update!(status: "draft")

      expect(plan.reload.version).to eq("1.1")

      plan.update!(status: "published")

      expect(plan.reload.version).to eq("1.1")
    end

    it "advances both when a plain content field changes" do
      plan.update!(status: "published")

      travel_to(Date.current + 3.days) do
        expect { plan.update!(contact_name: "Kai Ostermann") }
          .to change { plan.reload.version }.from("1.0").to("1.1")

        expect(plan.content_updated_at).to eq(Date.current)
      end
    end

    it "advances both when a translated content field changes" do
      plan.update!(status: "published")

      expect { plan.update!(processing_status: "Neuer Stand") }
        .to change { plan.reload.version }.from("1.0").to("1.1")
    end

    it "leaves both untouched when only the sort position changes" do
      expect { plan.update!(given_order: 5) }.not_to change { plan.reload.version }
    end

    it "leaves both untouched when the status changes without a first publication" do
      plan.update!(status: "published")

      expect { plan.update!(status: "archived") }.not_to change { plan.reload.version }
    end

    it "counts the minor part upwards without ever reaching 2" do
      plan.update!(status: "published")
      9.times { |n| plan.update!(contact_phone: "0364#{n}") }

      expect(plan.reload.version).to eq("1.9")

      plan.update!(contact_phone: "03649999")

      expect(plan.reload.version).to eq("1.10")

      plan.update!(contact_phone: "03648888")

      expect(plan.reload.version).to eq("1.11")
    end

    it "does not treat an internal note as a content change" do
      expect { plan.update!(internal_notes: "Nur intern") }.not_to change { plan.reload.version }
    end

    it "advances both when register_content_change! is called for an association edit" do
      expect { plan.register_content_change! }
        .to change { plan.reload.version }.from("0.1").to("0.2")
    end
  end

  describe "Bürgerbeteiligung formell and informell" do
    [[true, true], [true, false], [false, true], [false, false]].each do |formal, informal|
      it "accepts formell #{formal} with informell #{informal}" do
        plan = build(:municipal_plan, responsible: officer,
                                      formal_participation: formal,
                                      informal_participation: informal)

        expect(plan).to be_valid
      end
    end

    it "keeps a separate justification text for each" do
      plan = create(:municipal_plan, responsible: officer,
                                     formal_participation: false,
                                     informal_participation: true,
                                     formal_participation_reason: "Keine formelle Beteiligung vorgesehen",
                                     informal_participation_reason: "Bürgerwerkstatt im Herbst")

      expect(plan.reload.formal_participation_reason).to eq("Keine formelle Beteiligung vorgesehen")
      expect(plan.informal_participation_reason).to eq("Bürgerwerkstatt im Herbst")
    end
  end

  describe "Ortsteile" do
    it "accepts four districts" do
      plan = build(:municipal_plan, responsible: officer)
      plan.district_assignments.clear
      4.times { plan.district_assignments.build(district: create(:registered_address_district)) }

      expect(plan).to be_valid
    end

    it "rejects a fifth district" do
      plan = build(:municipal_plan, responsible: officer)
      plan.district_assignments.clear
      5.times { plan.district_assignments.build(district: create(:registered_address_district)) }

      expect(plan).not_to be_valid
      expect(plan.errors[:base])
        .to include(I18n.t("activerecord.errors.models.municipal_plan.too_many_districts", count: 4))
    end

    it "requires at least one district" do
      plan = build(:municipal_plan, responsible: officer)
      plan.district_assignments.clear

      expect(plan).not_to be_valid
    end
  end

  describe "Kartenposition" do
    it "requires a map location on create" do
      plan = build(:municipal_plan, responsible: officer)
      plan.map_location = nil

      expect(plan).not_to be_valid
      expect(plan.errors[:map_location]).to be_present
    end

    it "exposes the district derived from the pin" do
      plan = create(:municipal_plan, responsible: officer)

      expect(plan).to respond_to(:district)
      expect(plan.map_location).to be_present
    end
  end

  describe "topics" do
    it "requires at least one topic" do
      plan = build(:municipal_plan, responsible: officer)
      plan.topic_assignments.clear

      expect(plan).not_to be_valid
    end
  end
end
