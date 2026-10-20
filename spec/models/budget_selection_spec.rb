require "rails_helper"

describe Budget, "#selection_open?" do
  let(:budget) { create(:budget) }

  def current(kind)
    allow(budget).to receive(:current_phase).and_return(budget.phases.public_send(kind))
  end

  def disable(*kinds)
    budget.phases.where(kind: kinds).update_all(enabled: false)
  end

  context "when the price phase is enabled" do
    it "stays closed before it" do
      current("reviewing")

      expect(budget.selection_open?).to be false
    end

    it "opens with it" do
      current("publishing_prices")

      expect(budget.selection_open?).to be true
    end

    it "opens during the valuation phase" do
      current("valuating")

      expect(budget.selection_open?).to be true
    end

    it "stays closed during the support phase" do
      current("selecting")

      expect(budget.selection_open?).to be false
    end
  end

  context "when the price phase is disabled" do
    before { disable("publishing_prices") }

    it "opens once the review of proposals starts" do
      current("reviewing")

      expect(budget.selection_open?).to be true
    end

    it "opens during the support phase" do
      current("selecting")

      expect(budget.selection_open?).to be true
    end

    it "stays closed while proposals are still being submitted" do
      current("accepting")

      expect(budget.selection_open?).to be false
    end
  end

  it "opens from reviewing when support, valuation and price phases are all disabled" do
    disable("selecting", "valuating", "publishing_prices")
    current("reviewing")

    expect(budget.selection_open?).to be true
  end

  it "stays open during voting" do
    current("balloting")

    expect(budget.selection_open?).to be true
  end
end

describe Budget, "#selection_public?" do
  let(:investment) { create(:budget_investment) }
  let(:budget) { investment.budget }

  def current(kind)
    allow(budget).to receive(:current_phase).and_return(budget.phases.public_send(kind))
    allow(investment).to receive(:budget).and_return(budget)
  end

  def price_phase_starts_at(time)
    budget.phases.where(kind: "publishing_prices").update_all(starts_at: time)
  end

  context "when the price phase is enabled" do
    it "hides admissions during the valuation phase" do
      current("valuating")
      investment.selected = true

      expect(budget.selection_public?).to be false
      expect(investment.publicly_selected?).to be false
    end

    %w[publishing_prices balloting].each do |kind|
      it "shows admissions in the #{kind} phase" do
        price_phase_starts_at(1.day.ago)
        current(kind)
        investment.selected = true

        expect(budget.selection_public?).to be true
        expect(investment.publicly_selected?).to be true
      end
    end

    it "hides admissions when a date gap makes a later phase look current" do
      price_phase_starts_at(1.week.from_now)
      current("balloting")
      investment.selected = true

      expect(budget.selection_public?).to be false
      expect(investment.publicly_selected?).to be false
    end
  end

  it "shows admissions right away when the price phase is disabled" do
    budget.phases.where(kind: "publishing_prices").update_all(enabled: false)
    current("valuating")
    investment.selected = true

    expect(budget.selection_public?).to be true
    expect(investment.publicly_selected?).to be true
  end
end
