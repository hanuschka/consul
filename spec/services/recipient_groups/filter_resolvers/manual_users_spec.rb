require "rails_helper"

describe RecipientGroups::FilterResolvers::ManualUsers do
  let!(:u1)     { create(:user, email: "u1@x.test",  skip_password_validation: true) }
  let!(:u2)     { create(:user, email: "u2@x.test",  skip_password_validation: true) }
  let!(:erased) { create(:user, email: "e@x.test",   skip_password_validation: true, erased_at: Time.current) }

  it "returns emails of selected users (excluding erased)" do
    expect(
      described_class.new("user_ids" => [u1.id, u2.id, erased.id]).emails
    ).to contain_exactly("u1@x.test", "u2@x.test")
  end

  it "returns empty when no ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
