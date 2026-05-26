require "rails_helper"

describe RecipientGroups::FilterResolvers::AgeRange do
  let!(:young)  { create(:user, date_of_birth: 25.years.ago, email: "y@x.test", skip_password_validation: true) }
  let!(:mid)    { create(:user, date_of_birth: 40.years.ago, email: "m@x.test", skip_password_validation: true) }
  let!(:senior) { create(:user, date_of_birth: 70.years.ago, email: "s@x.test", skip_password_validation: true) }

  it "filters by min_age + max_age inline range" do
    expect(
      described_class.new("min_age" => 30, "max_age" => 50).emails
    ).to contain_exactly("m@x.test")
  end

  it "filters by configured age_range_id" do
    range = ::AgeRange.new
    range.name = "Seniors"
    range.min_age = 65
    range.max_age = 120
    range.save!
    expect(
      described_class.new("age_range_id" => range.id).emails
    ).to contain_exactly("s@x.test")
  end

  it "returns empty when no params given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
