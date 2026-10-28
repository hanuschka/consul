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
end
