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
