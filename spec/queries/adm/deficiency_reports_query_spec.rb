require "rails_helper"

describe Adm::DeficiencyReportsQuery do
  # The query calls params.permit, so it has to be handed controller params rather than a plain hash.
  def result(params, current_user: nil)
    Adm::DeficiencyReportsQuery.new(
      DeficiencyReport.all, ActionController::Parameters.new(params), current_user: current_user
    ).call
  end

  describe "assignment_scope filter" do
    let(:officer) { create(:deficiency_report_officer) }
    let(:user) { officer.user }
    let!(:mine) { create(:deficiency_report, responsible: officer) }
    let!(:watched) { create(:deficiency_report, responsible: create(:deficiency_report_officer)) }
    let!(:untouched) { create(:deficiency_report, responsible: create(:deficiency_report_officer)) }

    before { create(:deficiency_report_watch, deficiency_report: watched, user: user) }

    it "returns only the officer's own reports for assigned_to_me" do
      expect(result({ assignment_scope: ["assigned_to_me"] }, current_user: user))
        .to contain_exactly(mine)
    end

    it "returns only watched reports for watching" do
      expect(result({ assignment_scope: ["watching"] }, current_user: user))
        .to contain_exactly(watched)
    end

    # The three filter values are checkboxes, so the combination has to union rather than intersect.
    it "unions both when assigned_to_me and watching are selected" do
      expect(result({ assignment_scope: %w[assigned_to_me watching] }, current_user: user))
        .to contain_exactly(mine, watched)
    end

    it "returns everything for all" do
      expect(result({ assignment_scope: ["all"] }, current_user: user))
        .to contain_exactly(mine, watched, untouched)
    end

    it "returns everything when the filter is absent" do
      expect(result({}, current_user: user)).to contain_exactly(mine, watched, untouched)
    end

    it "returns everything when all is combined with a narrower value" do
      expect(result({ assignment_scope: %w[assigned_to_me all] }, current_user: user))
        .to contain_exactly(mine, watched, untouched)
    end

    it "ignores assigned_to_me for a user who is not an officer" do
      expect(result({ assignment_scope: ["assigned_to_me"] }, current_user: create(:user)))
        .to contain_exactly(mine, watched, untouched)
    end

    it "returns nothing for watching without a current user" do
      expect(result({ assignment_scope: ["watching"] })).to be_empty
    end
  end

  describe "subcategory filter" do
    let(:category) { create(:deficiency_report_category) }
    let(:subcategory) { create(:deficiency_report_subcategory, category: category) }
    let!(:matching) { create(:deficiency_report, category: category, subcategory: subcategory) }
    let!(:other) { create(:deficiency_report, category: category) }

    it "keeps only reports in the given subcategory" do
      expect(result({ deficiency_report_subcategory_id: [subcategory.id] })).to contain_exactly(matching)
    end

    it "returns everything when no subcategory is given" do
      expect(result({ deficiency_report_subcategory_id: [] })).to contain_exactly(matching, other)
    end
  end

  describe "hidden_state filter" do
    let!(:visible) { create(:deficiency_report) }
    let!(:hidden) { create(:deficiency_report).tap(&:destroy) }

    it "excludes deleted reports when no visibility is selected" do
      expect(result({ hidden_state: [""] })).to contain_exactly(visible)
    end

    it "excludes deleted reports when the param is missing" do
      expect(result({})).to contain_exactly(visible)
    end

    it "returns only deleted reports for hidden" do
      expect(result({ hidden_state: ["hidden"] })).to contain_exactly(hidden)
    end

    it "returns both for visible and hidden" do
      expect(result({ hidden_state: %w[visible hidden] })).to contain_exactly(visible, hidden)
    end
  end
end
