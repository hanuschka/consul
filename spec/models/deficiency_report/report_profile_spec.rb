require "rails_helper"

describe DeficiencyReport::ReportProfile do
  let(:profile) { build(:deficiency_report_report_profile) }

  it "is valid with the factory defaults" do
    expect(profile).to be_valid
  end

  it "needs at least one building block" do
    profile.building_blocks = [""]

    expect(profile).not_to be_valid
    expect(profile.errors[:building_blocks]).to eq [I18n.t("activerecord.errors.models.deficiency_report/report_profile.attributes.building_blocks.blank_selection")]
  end

  it "rejects unknown building blocks" do
    profile.building_blocks = ["incoming_and_closed", "everything"]

    expect(profile).not_to be_valid
    expect(profile.errors).to include(:building_blocks)
  end

  it "needs a recipient" do
    profile.recipient_emails = []

    expect(profile).not_to be_valid
    expect(profile.errors).to include(:recipient_user_ids)
  end

  it "accepts a user with deficiency report access as recipient" do
    officer = create(:deficiency_report_officer)
    profile.recipient_emails = []
    profile.recipient_user_ids = [officer.user_id.to_s]

    expect(profile).to be_valid
  end

  it "rejects a user without deficiency report access as recipient" do
    profile.recipient_user_ids = [create(:user).id]

    expect(profile).not_to be_valid
    expect(profile.errors).to include(:recipient_user_ids)
  end

  it "reads one e-mail address per line and normalizes them" do
    profile.recipient_emails_text = " Amt@Example.org\n\nbuero@example.org\namt@example.org "
    profile.validate

    expect(profile.recipient_emails).to eq ["amt@example.org", "buero@example.org"]
  end

  it "names invalid e-mail addresses" do
    profile.recipient_emails_text = "amt@example.org\nkein-eintrag"

    expect(profile).not_to be_valid
    expect(profile.errors[:recipient_emails_text].first).to include("kein-eintrag")
  end

  it "needs a weekday for a weekly schedule and drops the day of month" do
    profile.assign_attributes(frequency: "weekly", weekday: nil, day_of_month: 3)

    expect(profile).not_to be_valid
    expect(profile.errors).to include(:weekday)
    expect(profile.day_of_month).to be_nil
  end

  it "needs a day from 1 to 28 for a monthly schedule and drops the weekday" do
    profile.assign_attributes(frequency: "monthly", weekday: 5, day_of_month: 31)

    expect(profile).not_to be_valid
    expect(profile.errors).to include(:day_of_month)
    expect(profile.weekday).to be_nil
  end

  it "only lists active profiles in the active scope" do
    active = create(:deficiency_report_report_profile)
    create(:deficiency_report_report_profile, paused: true)

    expect(described_class.active).to eq [active]
  end

  describe "#next_period_start" do
    let(:profile) { create(:deficiency_report_report_profile) }
    let(:now) { Time.zone.local(2026, 10, 30, 15) }

    def report_for(profile, period_end:, sent_at:)
      DeficiencyReport::ManagementReport.create!(
        report_profile: profile, profile_name: profile.name, building_blocks: profile.building_blocks,
        period_start: period_end - 7.days, period_end: period_end, sent_at: sent_at
      )
    end

    it "goes back one week for a weekly profile without reports" do
      expect(profile.next_period_start(now)).to eq now - 7.days
    end

    it "goes back one month for a monthly profile without reports" do
      profile.update!(frequency: "monthly", day_of_month: 1)

      expect(profile.next_period_start(now)).to eq now - 1.month
    end

    it "starts where the last sent report ended" do
      report_for(profile, period_end: now - 2.days, sent_at: now - 2.days)

      expect(profile.next_period_start(now)).to eq now - 2.days
    end

    it "ignores reports that were not sent" do
      report_for(profile, period_end: now - 1.day, sent_at: nil)

      expect(profile.next_period_start(now)).to eq now - 7.days
    end
  end
end
