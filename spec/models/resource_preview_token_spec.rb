require "rails_helper"

describe ResourcePreviewToken do
  let(:purpose) { "on_behalf_of_preview" }
  let(:report)  { create(:deficiency_report) }

  def generate(resource = report, purpose: self.purpose, expires_in: 30.days)
    ResourcePreviewToken.generate(resource, purpose: purpose, expires_in: expires_in)
  end

  def verify(token, purpose: self.purpose)
    ResourcePreviewToken.resource_gid(token, purpose: purpose)
  end

  describe ".generate" do
    it "signs the resource's global id" do
      expect(verify(generate)).to eq(report.to_gid.to_s)
    end

    it "returns nothing for a blank resource" do
      expect(ResourcePreviewToken.generate(nil, purpose: purpose, expires_in: 30.days)).to be_nil
    end

    it "returns nothing for something that has no global id" do
      expect(ResourcePreviewToken.generate("a string", purpose: purpose, expires_in: 30.days)).to be_nil
    end
  end

  describe ".resource_gid" do
    it "names the one resource the pass was minted for" do
      other = create(:deficiency_report)

      expect(verify(generate)).to eq(report.to_gid.to_s)
      expect(verify(generate)).not_to eq(other.to_gid.to_s)
    end

    it "refuses a tampered pass" do
      expect(verify("#{generate}x")).to be_nil
    end

    it "refuses a pass minted for another purpose" do
      expect(verify(generate(purpose: "some_other_feature"))).to be_nil
    end

    it "refuses a pass read back under another purpose" do
      expect(verify(generate, purpose: "some_other_feature")).to be_nil
    end

    it "refuses an expired pass" do
      token = generate(expires_in: 30.days)

      travel_to(31.days.from_now) { expect(verify(token)).to be_nil }
    end

    it "still accepts a pass inside its window" do
      token = generate(expires_in: 30.days)

      travel_to(29.days.from_now) { expect(verify(token)).to eq(report.to_gid.to_s) }
    end

    it "refuses anything that is not a string" do
      expect(verify(nil)).to be_nil
      expect(verify("")).to be_nil
      expect(verify(["a", "b"])).to be_nil
      expect(verify(42)).to be_nil
    end

    # The caller gets an id rather than a record on purpose: a pass for a resource since deleted has
    # to come back as an id that resolves to nothing, not raise.
    it "still returns the id of a resource that has since been deleted" do
      token = generate
      gid = report.to_gid.to_s
      report.really_destroy!

      expect(verify(token)).to eq(gid)
      expect(GlobalID.parse(verify(token)).model_class.find_by(id: report.id)).to be_nil
    end
  end
end
