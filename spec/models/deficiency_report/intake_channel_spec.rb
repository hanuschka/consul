require "rails_helper"

describe DeficiencyReport::IntakeChannel do
  it "has a valid factory" do
    expect(build(:deficiency_report_intake_channel)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      expect(build(:deficiency_report_intake_channel, name: "")).not_to be_valid
    end
  end

  describe "associations" do
    it "has many deficiency reports through the intake channel column" do
      association = DeficiencyReport::IntakeChannel.reflect_on_association(:deficiency_reports)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:foreign_key]).to eq(:deficiency_report_intake_channel_id)
    end
  end

  describe "db columns" do
    it "stores the order as an integer and the default flag as a boolean" do
      columns = DeficiencyReport::IntakeChannel.columns_hash

      expect(columns["given_order"].type).to eq(:integer)
      expect(columns["default"].type).to eq(:boolean)
    end
  end

  describe "default scope" do
    it "orders by given_order ascending" do
      second = create(:deficiency_report_intake_channel, given_order: 2)
      first = create(:deficiency_report_intake_channel, given_order: 1)

      expect(DeficiencyReport::IntakeChannel.all.to_a).to eq([first, second])
    end
  end

  describe ".default" do
    it "returns the channel flagged as default" do
      create(:deficiency_report_intake_channel, given_order: 1)
      flagged = create(:deficiency_report_intake_channel, given_order: 2, default: true)

      expect(DeficiencyReport::IntakeChannel.default).to eq(flagged)
    end

    # Citizen submissions are stamped with this, so a client who never marked a channel still has to
    # get a consistent value rather than a blank one.
    it "falls back to the first channel when none is flagged" do
      first = create(:deficiency_report_intake_channel, given_order: 1)
      create(:deficiency_report_intake_channel, given_order: 2)

      expect(DeficiencyReport::IntakeChannel.default).to eq(first)
    end

    it "returns nil when there are no channels at all" do
      expect(DeficiencyReport::IntakeChannel.default).to be_nil
    end
  end

  describe "single default enforcement" do
    it "unsets the previous default when another one is flagged" do
      old_default = create(:deficiency_report_intake_channel, default: true)
      new_default = create(:deficiency_report_intake_channel, default: true)

      expect(old_default.reload.default).to be(false)
      expect(new_default.reload.default).to be(true)
    end

    it "leaves the flagged channel alone when a non-default one is saved" do
      flagged = create(:deficiency_report_intake_channel, default: true)
      create(:deficiency_report_intake_channel, default: false)

      expect(flagged.reload.default).to be(true)
    end
  end

  describe ".order_intake_channels" do
    it "renumbers given_order from the given id order" do
      first = create(:deficiency_report_intake_channel, given_order: 1)
      second = create(:deficiency_report_intake_channel, given_order: 2)

      DeficiencyReport::IntakeChannel.order_intake_channels([second.id, first.id])

      expect(second.reload.given_order).to eq(1)
      expect(first.reload.given_order).to eq(2)
    end
  end

  describe "#safe_to_destroy?" do
    let(:channel) { create(:deficiency_report_intake_channel) }

    it "is true while no report uses the channel" do
      expect(channel.safe_to_destroy?).to be(true)
    end

    it "is false once a report uses the channel" do
      create(:deficiency_report, intake_channel: channel)

      expect(channel.safe_to_destroy?).to be(false)
    end
  end
end
