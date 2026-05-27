require "rails_helper"

describe RecipientGroupResolver do
  let(:group) { create(:recipient_group) }

  def stub_resolver(kind, emails)
    klass = Class.new(RecipientGroups::FilterResolvers::Base) do
      define_method(:emails) { @stubbed_emails }
    end
    stub_const("RecipientGroups::FilterResolvers::#{kind.camelize}", klass)
    allow_any_instance_of(klass).to receive(:emails).and_return(emails)
  end

  def create_filter(recipient_group:, kind:, position:, operator:)
    f = build(:recipient_group_filter, recipient_group: recipient_group,
              kind: kind, position: position, operator: operator)
    f.save(validate: false)
    f
  end

  it "returns the first filter as the start set" do
    stub_resolver("kind_a", ["a@x", "b@x"])
    create_filter(recipient_group: group, kind: "kind_a", position: 1, operator: "include")

    expect(described_class.new(group).user_emails).to match_array(["a@x", "b@x"])
  end

  it "intersects the second filter" do
    stub_resolver("kind_a", ["a@x", "b@x", "c@x"])
    stub_resolver("kind_b", ["b@x", "c@x", "d@x"])
    create_filter(recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    create_filter(recipient_group: group, kind: "kind_b", position: 2, operator: "intersect")

    expect(described_class.new(group).user_emails).to match_array(["b@x", "c@x"])
  end

  it "excludes the second filter" do
    stub_resolver("kind_a", ["a@x", "b@x", "c@x"])
    stub_resolver("kind_b", ["b@x"])
    create_filter(recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    create_filter(recipient_group: group, kind: "kind_b", position: 2, operator: "exclude")

    expect(described_class.new(group).user_emails).to match_array(["a@x", "c@x"])
  end

  it "unions when second filter is include" do
    stub_resolver("kind_a", ["a@x"])
    stub_resolver("kind_b", ["b@x"])
    create_filter(recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    create_filter(recipient_group: group, kind: "kind_b", position: 2, operator: "include")

    expect(described_class.new(group).user_emails).to match_array(["a@x", "b@x"])
  end

  it "reports per-filter counts" do
    stub_resolver("kind_a", ["a@x", "b@x"])
    stub_resolver("kind_b", ["a@x"])
    f1 = create_filter(recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    f2 = create_filter(recipient_group: group, kind: "kind_b", position: 2, operator: "intersect")

    counts = described_class.new(group).per_filter_counts
    expect(counts).to eq([
      { id: f1.id, count: 2, delta: 2 },
      { id: f2.id, count: 1, delta: -1 }
    ])
  end

  it "returns 0 for an empty filter chain" do
    expect(described_class.new(group).count).to eq(0)
    expect(described_class.new(group).user_emails).to eq([])
  end
end
