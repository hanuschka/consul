require "rails_helper"

describe Adm::Projekts::BudgetPolicy do
  let(:budget) { create(:budget, :with_heading) }
  let(:admin) { create(:administrator).user }
  let(:policy) { Adm::Projekts::BudgetPolicy.new(admin, budget) }

  before do
    budget.phases.where.not(kind: "finished").update_all(enabled: false)
    budget.phases.where(kind: "finished").update_all(starts_at: 1.week.ago, ends_at: 1.week.from_now)
  end

  context "before winners are calculated" do
    it "offers calculating but not recalculating" do
      expect(policy.calculate_winners?).to be true
      expect(policy.recalculate_winners?).to be false
    end
  end

  context "once winners are calculated" do
    before { budget.update!(winners_calculated_at: Time.current) }

    it "offers recalculating but not calculating" do
      expect(policy.calculate_winners?).to be false
      expect(policy.recalculate_winners?).to be true
    end
  end

  context "with winners from before the calculation was recorded" do
    before do
      create(:budget_investment, heading: budget.heading, feasibility: "feasible", selected: true, winner: true)
    end

    it "offers recalculating but not calculating" do
      expect(policy.calculate_winners?).to be false
      expect(policy.recalculate_winners?).to be true
    end
  end
end
