require "rails_helper"

describe RecipientGroups::FilterResolvers::Geozone do
  let(:zone1) { create(:geozone) }
  let(:zone2) { create(:geozone) }
  # Use update_column to bypass the after_create callback that resets geozone_id via geozone_with_plz.
  let!(:in_zone1) do
    u = create(:user, email: "z1@x.test", skip_password_validation: true)
    u.update_column(:geozone_id, zone1.id)
    u
  end
  let!(:in_zone2) do
    u = create(:user, email: "z2@x.test", skip_password_validation: true)
    u.update_column(:geozone_id, zone2.id)
    u
  end
  let!(:no_zone) { create(:user, email: "nz@x.test", skip_password_validation: true) }

  it "returns users in selected geozones" do
    expect(
      described_class.new("geozone_ids" => [zone1.id]).emails
    ).to contain_exactly("z1@x.test")
  end

  it "returns users across multiple geozones" do
    expect(
      described_class.new("geozone_ids" => [zone1.id, zone2.id]).emails
    ).to contain_exactly("z1@x.test", "z2@x.test")
  end

  it "returns empty when no geozone_ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
