require "rails_helper"

describe RecipientGroups::FilterResolvers::District do
  let(:district1) { RegisteredAddress::District.create!(name: "District 1") }
  let(:district2) { RegisteredAddress::District.create!(name: "District 2") }

  let(:address_in_district1) do
    ra = create(:registered_address)
    ra.update_column(:registered_address_district_id, district1.id)
    ra
  end

  let(:address_in_district2) do
    ra = create(:registered_address)
    ra.update_column(:registered_address_district_id, district2.id)
    ra
  end

  let!(:in_district1) do
    create(:user, email: "d1@x.test", registered_address: address_in_district1, skip_password_validation: true)
  end

  let!(:in_district2) do
    create(:user, email: "d2@x.test", registered_address: address_in_district2, skip_password_validation: true)
  end

  let!(:no_district) { create(:user, email: "nd@x.test", skip_password_validation: true) }

  it "returns users in selected districts" do
    expect(
      described_class.new("district_ids" => [district1.id]).emails
    ).to contain_exactly("d1@x.test")
  end

  it "returns users across multiple districts" do
    expect(
      described_class.new("district_ids" => [district1.id, district2.id]).emails
    ).to contain_exactly("d1@x.test", "d2@x.test")
  end

  it "returns empty when no district_ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
