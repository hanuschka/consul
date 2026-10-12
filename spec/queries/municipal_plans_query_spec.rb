require "rails_helper"

describe MunicipalPlansQuery do
  let(:officer) { create(:municipal_plan_officer) }
  let(:zentrum) { create(:registered_address_district) }
  let(:zwaetzen) { create(:registered_address_district) }
  let(:lobeda) { create(:registered_address_district) }
  let(:bauen) { create(:municipal_plan_topic) }
  let(:mobilitaet) { create(:municipal_plan_topic) }

  def plan_with(districts:, topics:, formal: false, informal: false)
    plan = build(:municipal_plan, :published, responsible: officer,
                                              formal_participation: formal,
                                              informal_participation: informal)
    plan.district_assignments.clear
    plan.topic_assignments.clear
    districts.each { |d| plan.district_assignments.build(district: d) }
    topics.each { |t| plan.topic_assignments.build(topic: t) }
    plan.save!
    plan
  end

  def resolve(params)
    described_class.new(MunicipalPlan.published, params).call
  end

  describe "combining filters" do
    let!(:a) { plan_with(districts: [zentrum], topics: [bauen]) }
    let!(:b) { plan_with(districts: [zwaetzen], topics: [bauen]) }
    let!(:c) { plan_with(districts: [lobeda], topics: [bauen]) }
    let!(:d) { plan_with(districts: [zentrum], topics: [mobilitaet]) }

    it "returns plans matching either Ortsteil and the chosen Thema" do
      result = resolve(districts: [zentrum.id, zwaetzen.id], topics: [bauen.id])

      expect(result).to match_array([a, b])
    end

    it "widens when the Thema filter is cleared, keeping the Ortsteile" do
      result = resolve(districts: [zentrum.id, zwaetzen.id])

      expect(result).to match_array([a, b, d])
    end

    it "widens differently when the Ortsteil filter is cleared, keeping the Thema" do
      result = resolve(topics: [bauen.id])

      expect(result).to match_array([a, b, c])
    end

    it "returns everything with no filters" do
      expect(resolve({})).to match_array([a, b, c, d])
    end
  end

  describe "participation" do
    let!(:formal_only) { plan_with(districts: [zentrum], topics: [bauen], formal: true) }
    let!(:informal_only) { plan_with(districts: [zentrum], topics: [bauen], informal: true) }
    let!(:neither) { plan_with(districts: [zentrum], topics: [bauen]) }

    it "filters to the formal flag" do
      result = resolve(participation: ["formal"])

      expect(result).to match_array([formal_only])
      expect(result).not_to include(neither)
    end

    it "widens across both flags" do
      expect(resolve(participation: %w[formal informal]))
        .to match_array([formal_only, informal_only])
    end
  end

  describe "recency" do
    let!(:fresh) { plan_with(districts: [zentrum], topics: [bauen]) }
    let!(:updated) { plan_with(districts: [zentrum], topics: [bauen]) }
    let!(:stale) { plan_with(districts: [zentrum], topics: [bauen]) }

    before do
      updated.update_columns(created_at: 400.days.ago, content_updated_at: Date.current - 10)
      stale.update_columns(created_at: 400.days.ago, content_updated_at: Date.current - 400)
    end

    it "finds newly added plans" do
      expect(resolve(recency: ["new"])).to match_array([fresh])
    end

    it "finds recently updated plans without the new ones" do
      expect(resolve(recency: ["updated"])).to match_array([updated])
    end

    it "widens across both values" do
      expect(resolve(recency: %w[new updated])).to match_array([fresh, updated])
    end

    it "agrees with the model scopes" do
      expect(resolve(recency: ["new"])).to match_array(MunicipalPlan.published.newly_added)
      expect(resolve(recency: ["updated"])).to match_array(MunicipalPlan.published.recently_updated)
    end
  end

  describe "Aktualisierungsdatum range" do
    let!(:recent) { plan_with(districts: [zentrum], topics: [bauen]) }
    let!(:old) { plan_with(districts: [zentrum], topics: [bauen]) }

    before { old.update_columns(content_updated_at: Date.current - 400) }

    it "filters from a date" do
      expect(resolve(updated_from: (Date.current - 5).to_s)).to match_array([recent])
    end

    it "filters up to a date" do
      expect(resolve(updated_to: (Date.current - 5).to_s)).to match_array([old])
    end

    it "ignores an unparseable date" do
      expect(resolve(updated_from: "not-a-date")).to match_array([recent, old])
    end
  end

  describe "junk input" do
    let!(:plan) { plan_with(districts: [zentrum], topics: [bauen]) }

    it "ignores a non-numeric district instead of returning nothing" do
      expect(resolve(districts: ["abc"])).to match_array([plan])
    end

    it "ignores an unknown participation value" do
      expect(resolve(participation: ["sideways"])).to match_array([plan])
    end
  end
end
