require "rails_helper"

describe RecipientGroups::FilterResolvers::Role do
  let!(:admin) do
    create(:administrator, user: create(:user, skip_password_validation: true)).user.tap do |u|
      u.update_column(:email, "admin@x.test")
    end
  end
  let!(:moderator) do
    create(:moderator, user: create(:user, skip_password_validation: true)).user.tap do |u|
      u.update_column(:email, "mod@x.test")
    end
  end
  let!(:regular) { create(:user, email: "reg@x.test", skip_password_validation: true) }

  it "returns administrators" do
    expect(described_class.new("role" => "administrator").emails).to contain_exactly("admin@x.test")
  end

  it "returns moderators" do
    expect(described_class.new("role" => "moderator").emails).to contain_exactly("mod@x.test")
  end

  it "returns empty for unsupported role" do
    expect(described_class.new("role" => "bogus").emails).to eq([])
  end
end
