require "rails_helper"

describe DeficiencyReport do
  it "has a valid factory" do
    expect(build(:deficiency_report)).to be_valid
  end

  describe "intake channel" do
    describe "#intake_channel_required?" do
      it "is false while the setting is off" do
        create(:deficiency_report_intake_channel)
        set_setting("deficiency_reports.intake_channel_required_for_on_behalf_of", false)

        expect(build(:deficiency_report, :on_behalf_of).intake_channel_required?).to be(false)
      end

      it "is false for a report the citizen filed themselves" do
        create(:deficiency_report_intake_channel)
        set_setting("deficiency_reports.intake_channel_required_for_on_behalf_of", true)

        expect(build(:deficiency_report).intake_channel_required?).to be(false)
      end

      # Without this guard, switching the setting on before configuring any channel would block
      # every on-behalf-of submission behind a field nobody can fill.
      it "is false while no channel is configured" do
        set_setting("deficiency_reports.intake_channel_required_for_on_behalf_of", true)

        expect(build(:deficiency_report, :on_behalf_of).intake_channel_required?).to be(false)
      end

      it "is true for an on-behalf-of report once channels exist and the setting is on" do
        create(:deficiency_report_intake_channel)
        set_setting("deficiency_reports.intake_channel_required_for_on_behalf_of", true)

        expect(build(:deficiency_report, :on_behalf_of).intake_channel_required?).to be(true)
      end
    end

    describe "validation" do
      before { set_setting("deficiency_reports.intake_channel_required_for_on_behalf_of", true) }

      it "rejects an on-behalf-of report without a channel" do
        create(:deficiency_report_intake_channel)
        report = build(:deficiency_report, :on_behalf_of)

        expect(report).not_to be_valid
        expect(report.errors[:deficiency_report_intake_channel_id]).to be_present
      end

      it "accepts an on-behalf-of report that names a channel" do
        channel = create(:deficiency_report_intake_channel)

        expect(build(:deficiency_report, :on_behalf_of, intake_channel: channel)).to be_valid
      end
    end

    describe "default channel" do
      it "stamps a citizen submission with the configured default" do
        create(:deficiency_report_intake_channel, given_order: 1)
        default = create(:deficiency_report_intake_channel, given_order: 2, default: true)

        expect(create(:deficiency_report).intake_channel).to eq(default)
      end

      it "keeps a channel that was chosen explicitly" do
        chosen = create(:deficiency_report_intake_channel, given_order: 1)
        create(:deficiency_report_intake_channel, given_order: 2, default: true)

        expect(create(:deficiency_report, intake_channel: chosen).intake_channel).to eq(chosen)
      end

      it "leaves the channel blank while none is configured" do
        expect(create(:deficiency_report).intake_channel).to be_nil
      end

      # An on-behalf-of report under the setting has to be answered by staff, so it must not be
      # quietly stamped with the default instead.
      it "does not stamp an on-behalf-of report when the channel is mandatory" do
        create(:deficiency_report_intake_channel, default: true)
        set_setting("deficiency_reports.intake_channel_required_for_on_behalf_of", true)

        report = build(:deficiency_report, :on_behalf_of)
        report.valid?

        expect(report.intake_channel).to be_nil
      end
    end
  end

  describe "subcategory consistency" do
    let(:category) { create(:deficiency_report_category) }
    let(:subcategory) { create(:deficiency_report_subcategory, category: category) }

    it "keeps a subcategory that belongs to the report's category" do
      report = create(:deficiency_report, category: category, subcategory: subcategory)

      expect(report.subcategory).to eq(subcategory)
    end

    it "drops a subcategory that belongs to a different category" do
      report = create(:deficiency_report, category: create(:deficiency_report_category),
                      subcategory: subcategory)

      expect(report.subcategory).to be_nil
    end

    it "drops the subcategory when the report is moved to another category" do
      report = create(:deficiency_report, category: category, subcategory: subcategory)

      report.update!(category: create(:deficiency_report_category))

      expect(report.reload.subcategory).to be_nil
    end
  end

  describe "watching" do
    let(:report) { create(:deficiency_report) }
    let(:user) { create(:user) }

    describe "#watched_by?" do
      it "is true for a user with the bell on" do
        create(:deficiency_report_watch, deficiency_report: report, user: user)

        expect(report.reload.watched_by?(user)).to be(true)
      end

      it "is false for a user without a watch" do
        expect(report.watched_by?(user)).to be(false)
      end

      it "is false without a user" do
        expect(report.watched_by?(nil)).to be(false)
      end
    end

    describe ".watched_by" do
      it "returns only the reports the user watches" do
        create(:deficiency_report_watch, deficiency_report: report, user: user)
        other_report = create(:deficiency_report)

        expect(DeficiencyReport.watched_by(user)).to include(report)
        expect(DeficiencyReport.watched_by(user)).not_to include(other_report)
      end

      it "returns nothing without a user" do
        create(:deficiency_report_watch, deficiency_report: report, user: user)

        expect(DeficiencyReport.watched_by(nil)).to be_empty
      end
    end
  end

  describe ".assigned_to_officer" do
    let(:officer) { create(:deficiency_report_officer) }

    it "returns reports the officer is responsible for in person" do
      report = create(:deficiency_report, responsible: officer)

      expect(DeficiencyReport.assigned_to_officer(officer)).to contain_exactly(report)
    end

    it "returns reports assigned to one of the officer's groups" do
      group = create(:deficiency_report_officer_group)
      create(:deficiency_report_officer_group_assignment, officer: officer, officer_group: group)
      report = create(:deficiency_report, responsible: group)

      expect(DeficiencyReport.assigned_to_officer(officer)).to contain_exactly(report)
    end

    it "does not return reports assigned to a group the officer is not in" do
      create(:deficiency_report, responsible: create(:deficiency_report_officer_group))

      expect(DeficiencyReport.assigned_to_officer(officer)).to be_empty
    end

    it "does not return reports assigned to another officer" do
      create(:deficiency_report, responsible: create(:deficiency_report_officer))

      expect(DeficiencyReport.assigned_to_officer(officer)).to be_empty
    end

    it "returns nothing without an officer" do
      create(:deficiency_report, responsible: officer)

      expect(DeficiencyReport.assigned_to_officer(nil)).to be_empty
    end
  end

  describe "#assign_default_responsible" do
    let(:category_responsible) { create(:deficiency_report_officer_group) }
    let(:category) { create(:deficiency_report_category, default_responsible: category_responsible) }

    it "uses the category's default responsible" do
      report = create(:deficiency_report, category: category)

      report.assign_default_responsible

      expect(report.reload.responsible).to eq(category_responsible)
      expect(report.assigned_at).to be_present
    end

    # A subcategory is the more specific statement of who owns this kind of report, so it wins over
    # the category it hangs under.
    it "prefers the subcategory's default responsible over the category's" do
      subcategory_responsible = create(:deficiency_report_officer_group)
      subcategory = create(:deficiency_report_subcategory, category: category,
                           default_responsible: subcategory_responsible)
      report = create(:deficiency_report, category: category, subcategory: subcategory)

      report.assign_default_responsible

      expect(report.reload.responsible).to eq(subcategory_responsible)
    end

    it "prefers the district's default responsible over both" do
      district_responsible = create(:deficiency_report_officer_group)
      district = RegisteredAddress::District.create!(
        name: "District 1", default_deficiency_report_responsible: district_responsible
      )
      subcategory = create(:deficiency_report_subcategory, category: category,
                           default_responsible: create(:deficiency_report_officer_group))
      report = create(:deficiency_report, category: category, subcategory: subcategory)
      # MapLocation recomputes the district from geometry in after_save, so the column has to be
      # written past the callbacks — there are no district polygons in the test database.
      report.map_location.update_column(:registered_address_district_id, district.id)

      report.reload.assign_default_responsible

      expect(report.reload.responsible).to eq(district_responsible)
    end

    it "leaves the report unassigned when nothing carries a default" do
      report = create(:deficiency_report)

      report.assign_default_responsible

      expect(report.reload.responsible).to be_nil
      expect(report.assigned_at).to be_nil
    end
  end
end
