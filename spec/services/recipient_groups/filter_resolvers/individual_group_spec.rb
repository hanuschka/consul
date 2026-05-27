require "rails_helper"

describe RecipientGroups::FilterResolvers::IndividualGroup do
  let(:group)   { create(:individual_group) }
  let(:value_a) { create(:individual_group_value, individual_group: group) }
  let(:value_b) { create(:individual_group_value, individual_group: group) }
  let!(:member_a) { create(:user, email: "a@x.test", skip_password_validation: true) }
  let!(:member_b) { create(:user, email: "b@x.test", skip_password_validation: true) }
  let!(:outsider)  { create(:user, email: "o@x.test", skip_password_validation: true) }

  before do
    create(:user_individual_group_value, user: member_a, individual_group_value: value_a)
    create(:user_individual_group_value, user: member_b, individual_group_value: value_b)
  end

  it "returns members of selected individual group values" do
    expect(
      described_class.new("individual_group_value_ids" => [value_a.id]).emails
    ).to contain_exactly("a@x.test")
  end

  it "supports multiple values (union within filter)" do
    expect(
      described_class.new("individual_group_value_ids" => [value_a.id, value_b.id]).emails
    ).to contain_exactly("a@x.test", "b@x.test")
  end

  it "returns empty when no ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
