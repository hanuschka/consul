require "rails_helper"

describe Budget::Ballot do
  describe "#add_investment" do
    let(:investment) { create(:budget_investment, feasibility: "feasible", selected: true) }
    let(:ballot) { Budget::Ballot.create!(user: create(:user), budget: investment.budget) }

    it "adds an investment only once when it is added twice" do
      expect(ballot.add_investment(investment)).to be true
      expect(ballot.add_investment(investment)).to be false
      expect(ballot.lines.count).to eq 1
    end
  end
end
