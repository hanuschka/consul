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

  describe "Entwurf und Freigabe" do
    def missing_field_message(field)
      I18n.t("activerecord.errors.models.municipal_plan.release_required",
             field: MunicipalPlan.human_attribute_name(field))
    end

    it "saves an Entwurf that carries nothing but a Titel" do
      expect(MunicipalPlan.new(title: "Nur ein Titel")).to be_valid
    end

    it "still refuses an Entwurf without a Titel" do
      expect(MunicipalPlan.new).not_to be_valid
    end

    it "names every missing field when that Entwurf is published" do
      plan = MunicipalPlan.new(title: "Nur ein Titel", status: "published")

      expect(plan).not_to be_valid

      MunicipalPlan::RELEASE_REQUIRED_FIELDS.each do |field|
        expect(plan.errors[:base]).to include(missing_field_message(field))
      end

      expect(plan.errors[:base])
        .to include(I18n.t("activerecord.errors.models.municipal_plan.districts_required"))
      expect(plan.errors[:base])
        .to include(I18n.t("activerecord.errors.models.municipal_plan.topics_required"))
    end

    it "counts an emptied rich text field as missing" do
      plan = build(:municipal_plan, responsible: officer, status: "published",
                                    processing_status: "<p>&nbsp;</p>")

      expect(plan).not_to be_valid
      expect(plan.errors[:base]).to include(missing_field_message(:processing_status))
    end

    it "publishes once every required field is filled" do
      expect(build(:municipal_plan, :published, responsible: officer)).to be_valid
    end

    it "refuses to archive an Entwurf that was never complete" do
      expect(MunicipalPlan.new(title: "Nur ein Titel", status: "archived")).not_to be_valid
    end
  end

  describe "badges" do
    let(:plan) { create(:municipal_plan, responsible: officer) }

    def age(created:, updated:)
      plan.update_columns(created_at: created.days.ago, content_updated_at: Date.current - updated)
      plan.reload
    end

    it "marks a brand new Vorhaben as new, not as updated" do
      expect(plan.badges).to include(:new)
      expect(plan.badges).not_to include(:updated)
    end

    it "marks a Vorhaben updated 29 days ago as updated" do
      age(created: 400, updated: 29)

      expect(plan.badges).to include(:updated)
    end

    it "leaves a Vorhaben updated 31 days ago unmarked" do
      age(created: 400, updated: 31)

      expect(plan.badges).not_to include(:updated)
      expect(plan.badges).not_to include(:new)
    end

    it "carries neither badge when both dates are backdated, as after an import" do
      age(created: 400, updated: 400)

      expect(plan.badges & %i[new updated]).to be_empty
    end

    it "shows the participation flags that are set" do
      plan.update!(formal_participation: false, informal_participation: true)

      expect(plan.badges).to include(:informal_participation)
      expect(plan.badges).not_to include(:formal_participation)
    end

    describe "scopes" do
      it "finds new Vorhaben" do
        fresh = plan
        old = create(:municipal_plan, responsible: officer)
        old.update_columns(created_at: 400.days.ago, content_updated_at: Date.current - 400)

        expect(MunicipalPlan.newly_added).to eq([fresh])
      end

      it "finds updated Vorhaben without the new ones" do
        plan
        updated = create(:municipal_plan, responsible: officer)
        updated.update_columns(created_at: 400.days.ago, content_updated_at: Date.current - 29)

        expect(MunicipalPlan.recently_updated).to eq([updated])
      end
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

    it "requires at least one district for publication" do
      plan = build(:municipal_plan, :published, responsible: officer)
      plan.district_assignments.clear

      expect(plan).not_to be_valid
    end

    it "lets an Entwurf go without one" do
      plan = build(:municipal_plan, responsible: officer)
      plan.district_assignments.clear

      expect(plan).to be_valid
    end
  end

  describe "Kartenposition" do
    it "requires a map location for publication" do
      plan = build(:municipal_plan, :published, responsible: officer)
      plan.map_location = nil

      expect(plan).not_to be_valid
      expect(plan.errors[:base])
        .to include(I18n.t("activerecord.errors.models.municipal_plan.release_required",
                           field: MunicipalPlan.human_attribute_name(:map_location)))
    end

    it "lets an Entwurf go without one" do
      plan = build(:municipal_plan, responsible: officer)
      plan.map_location = nil

      expect(plan).to be_valid
    end

    it "exposes the district derived from the pin" do
      plan = create(:municipal_plan, responsible: officer)

      expect(plan).to respond_to(:district)
      expect(plan.map_location).to be_present
    end
  end

  describe "topics" do
    it "requires at least one topic for publication" do
      plan = build(:municipal_plan, :published, responsible: officer)
      plan.topic_assignments.clear

      expect(plan).not_to be_valid
    end

    it "lets an Entwurf go without one" do
      plan = build(:municipal_plan, responsible: officer)
      plan.topic_assignments.clear

      expect(plan).to be_valid
    end
  end
end
