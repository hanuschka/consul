require "rails_helper"

describe Budget::Investment, "feasibility" do
  let(:budget) { create(:budget, :with_heading) }

  def investment(feasibility, **attrs)
    create(:budget_investment, heading: budget.heading, feasibility:, **attrs)
  end

  describe "with changes" do
    let!(:accepted) { investment("feasible") }
    let!(:with_changes) { investment("with_changes") }
    let!(:declined) { investment("unfeasible") }
    let!(:undecided) { investment("undecided") }

    it "counts as feasible" do
      expect(with_changes).to be_feasible
      expect(with_changes).to be_with_changes
      expect(accepted).not_to be_with_changes
    end

    it "is listed with the accepted ideas" do
      expect(budget.investments.feasible).to contain_exactly(accepted, with_changes)
      expect(budget.investments.unfeasible).to contain_exactly(declined)
      expect(budget.investments.not_unfeasible).to include(with_changes)
    end

    it "can be selected" do
      with_changes.update!(selected: true)

      expect(budget.investments.selected).to contain_exactly(with_changes)
    end

    it "takes part in the preselection" do
      budget.update!(max_preselected: 1)
      with_changes.update_column(:physical_votes, 10)

      budget.update_preselected_investments

      expect(with_changes.reload).to be_preselected
      expect(accepted.reload).not_to be_preselected
    end
  end

  describe "public explanation" do
    it "is shown once the assessment with changes is finished, before selection" do
      record = investment("with_changes", valuation_finished: true, valuator_explanation: "Standort verlegt")

      expect(record).to be_should_show_feasibility_explanation
    end

    it "is shown for a finished accepted idea" do
      record = investment("feasible", valuation_finished: true, valuator_explanation: "Machbar")

      expect(record).to be_should_show_feasibility_explanation
    end

    it "is hidden while the assessment is not finished" do
      record = investment("with_changes", valuator_explanation: "Standort verlegt")

      expect(record).not_to be_should_show_feasibility_explanation
    end
  end

  describe "explanation" do
    it "is required for a finished assessment with changes" do
      record = investment("with_changes")
      record.assign_attributes(valuation_finished: true, valuator_explanation: "")

      expect(record).not_to be_valid
      expect(record.errors).to include(:valuator_explanation)
    end

    it "is not required before the assessment is finished" do
      record = investment("with_changes")
      record.assign_attributes(valuator_explanation: "")

      expect(record).to be_valid
    end

    it "is not required for an accepted idea" do
      record = investment("feasible")
      record.assign_attributes(valuation_finished: true, valuator_explanation: "")

      expect(record).to be_valid
    end
  end
end
