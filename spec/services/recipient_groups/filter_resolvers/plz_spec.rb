require "rails_helper"

describe RecipientGroups::FilterResolvers::Plz do
  # User.plz is INTEGER in the database. The resolver converts string list to integers.
  # Use update_column for plz to bypass any callbacks that might reset it.
  let!(:a) do
    u = create(:user, email: "a@x.test", skip_password_validation: true)
    u.update_column(:plz, 80331)
    u
  end
  let!(:b) do
    u = create(:user, email: "b@x.test", skip_password_validation: true)
    u.update_column(:plz, 80333)
    u
  end
  let!(:c) do
    u = create(:user, email: "c@x.test", skip_password_validation: true)
    u.update_column(:plz, 99999)
    u
  end

  it "matches exact PLZ values" do
    expect(
      described_class.new("plz_list" => ["80331", "80333"]).emails
    ).to contain_exactly("a@x.test", "b@x.test")
  end

  it "returns empty when list is empty" do
    expect(described_class.new("plz_list" => []).emails).to eq([])
  end
end
