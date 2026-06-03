require "rails_helper"

describe RecipientGroups::FilterResolvers::Gender do
  let!(:f)  { create(:user, gender: "female",    email: "f@x.test",  skip_password_validation: true) }
  let!(:m)  { create(:user, gender: "male",      email: "m@x.test",  skip_password_validation: true) }
  let!(:nb) { create(:user, gender: "other_gen", email: "nb@x.test", skip_password_validation: true) }

  it "filters by gender value female" do
    expect(described_class.new("gender" => "female").emails).to contain_exactly("f@x.test")
  end

  it "filters by gender value male" do
    expect(described_class.new("gender" => "male").emails).to contain_exactly("m@x.test")
  end

  it "returns empty for unknown gender" do
    expect(described_class.new("gender" => "xx").emails).to eq([])
  end

  it "returns empty when blank" do
    expect(described_class.new({}).emails).to eq([])
  end
end
