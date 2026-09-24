require "rails_helper"

describe AuditsHelper do
  let(:plan) { build(:municipal_plan) }

  describe "#audit_value" do
    it "formats a stored timestamp as date and time" do
      expect(helper.audit_value(plan, "released_at", "2026-09-24T11:19:39.778+02:00"))
        .to eq("24.09.2026 11:19")
    end

    it "leaves an empty timestamp empty" do
      expect(helper.audit_value(plan, "released_at", nil)).to eq("")
    end

    it "keeps other values as they are" do
      expect(helper.audit_value(plan, "internal_notes", "Neu")).to eq("Neu")
    end
  end
end
