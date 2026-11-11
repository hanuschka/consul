require "rails_helper"

describe Budget::Result do
  describe "#calculate_winners" do
    let(:budget) { create(:budget, :with_heading) }
    let(:heading) { budget.heading }

    before { heading.update!(price: 1000) }

    def investment(price:, ballots:)
      create(:budget_investment, heading: heading, feasibility: "feasible", selected: true,
                                 price: price, ballot_lines_count: ballots)
    end

    def calculate
      Budget::Result.new(budget.reload, heading).calculate_winners
    end

    context "with money shown" do
      let!(:first) { investment(price: 300, ballots: 50) }
      let!(:too_expensive) { investment(price: 800, ballots: 40) }
      let!(:second) { investment(price: 300, ballots: 30) }
      let!(:third) { investment(price: 300, ballots: 20) }

      it "stops at the maximum number of winners and still skips investments over budget" do
        budget.update!(max_number_of_winners: 2)

        calculate

        expect(Budget::Investment.where(winner: true)).to match_array [first, second]
      end

      [nil, 0].each do |value|
        it "fills the budget without a cap when the maximum is #{value.inspect}" do
          budget.update!(max_number_of_winners: value)

          calculate

          expect(Budget::Investment.where(winner: true)).to match_array [first, second, third]
        end
      end

      it "clears former winners that are hidden or no longer selected" do
        hidden = investment(price: 100, ballots: 100)
        unselected = investment(price: 100, ballots: 100)
        hidden.update_columns(winner: true, hidden_at: Time.current)
        unselected.update_columns(winner: true, selected: false)

        calculate

        expect(Budget::Investment.with_hidden.where(winner: true)).to match_array [first, second, third]
      end

      it "ignores investments without a price" do
        unpriced = investment(price: nil, ballots: 100)

        expect { calculate }.not_to raise_error
        expect(unpriced.reload).not_to be_winner
        expect(Budget::Investment.where(winner: true)).to match_array [first, second, third]
      end
    end

    context "with money hidden" do
      let!(:first) { investment(price: nil, ballots: 50) }
      let!(:second) { investment(price: nil, ballots: 40) }
      let!(:third) { investment(price: nil, ballots: 30) }

      before { budget.update!(hide_money: true) }

      it "selects the top investments up to the maximum number of winners" do
        budget.update!(max_number_of_winners: 2)

        calculate

        expect(Budget::Investment.where(winner: true)).to match_array [first, second]
      end

      [nil, 0].each do |value|
        it "selects all compatible investments when the maximum is #{value.inspect}" do
          budget.update!(max_number_of_winners: value)

          calculate

          expect(Budget::Investment.where(winner: true)).to match_array [first, second, third]
        end
      end
    end

    context "with a tie at the maximum number of winners" do
      let!(:leader) { investment(price: nil, ballots: 50) }
      let!(:tied) { [investment(price: nil, ballots: 40), investment(price: nil, ballots: 40)] }
      let!(:below) { investment(price: nil, ballots: 30) }

      before { budget.update!(hide_money: true, max_number_of_winners: 2) }

      it "only marks the investments above the tie as winners" do
        calculate

        expect(Budget::Investment.where(winner: true)).to eq [leader]
      end

      it "reports the tied investments and the free places" do
        calculate
        tie = Budget::Result.new(budget.reload, heading).pending_tie

        expect(tie.candidates).to match_array tied
        expect(tie.free_places).to eq 1
        expect(tie.remaining_budget).to be nil
      end

      it "is not a tie when all tied investments fit" do
        budget.update!(max_number_of_winners: 3)

        calculate

        expect(Budget::Investment.where(winner: true)).to match_array [leader, *tied]
        expect(Budget::Result.new(budget.reload, heading).pending_tie).to be nil
      end
    end

    context "with a tie on the remaining budget" do
      let!(:leader) { investment(price: 300, ballots: 50) }
      let!(:tied) { [investment(price: 600, ballots: 40), investment(price: 600, ballots: 40)] }
      let!(:below) { investment(price: 100, ballots: 30) }

      it "stops at the tie without filling the remaining budget from below" do
        calculate

        expect(Budget::Investment.where(winner: true)).to eq [leader]
      end

      it "reports the tied investments and the remaining budget" do
        calculate
        tie = Budget::Result.new(budget.reload, heading).pending_tie

        expect(tie.candidates).to match_array tied
        expect(tie.free_places).to be nil
        expect(tie.remaining_budget).to eq 700
      end

      it "is not a tie when only one tied investment fits the remaining budget" do
        tied.first.update!(price: 800)

        calculate

        expect(Budget::Investment.where(winner: true)).to match_array [leader, tied.last, below]
        expect(Budget::Result.new(budget.reload, heading).pending_tie).to be nil
      end
    end

    describe "#resolve_tie" do
      let!(:leader) { investment(price: 300, ballots: 50) }
      let!(:tied) { [investment(price: 400, ballots: 40), investment(price: 400, ballots: 40), investment(price: 400, ballots: 40)] }
      let!(:below) { investment(price: 100, ballots: 30) }

      before { calculate }

      def resolve(picked)
        Budget::Result.new(budget.reload, heading).resolve_tie(picked.map { it.id.to_s })
      end

      it "marks the investments above the tie and the picked ones as winners" do
        expect(resolve([tied.first])).to be true

        expect(Budget::Investment.where(winner: true)).to match_array [leader, tied.first]
        expect(budget.reload.tie_resolved_at).to be_present
      end

      it "allows picking fewer than fit, leaving the rest unfilled" do
        expect(resolve([])).to be true

        expect(Budget::Investment.where(winner: true)).to eq [leader]
        expect(Budget::Result.new(budget.reload, heading).pending_tie).to be nil
      end

      it "rejects picks over the remaining budget" do
        expect(resolve(tied.first(2))).to be false

        expect(budget.reload.tie_resolved_at).to be nil
      end

      it "rejects picks over the free places" do
        budget.update!(hide_money: true, max_number_of_winners: 2)

        expect(resolve(tied.first(2))).to be false
        expect(resolve(tied.first(1))).to be true
      end

      it "rejects investments outside the tie" do
        expect(resolve([below])).to be false

        expect(below.reload).not_to be_winner
        expect(budget.reload.tie_resolved_at).to be nil
      end

      it "rejects a second resolution" do
        resolve([tied.first])

        expect(resolve([tied.last])).to be false
        expect(tied.last.reload).not_to be_winner
      end
    end

    describe "#pending_tie" do
      before do
        investment(price: nil, ballots: 40)
        investment(price: nil, ballots: 40)
        budget.update!(hide_money: true, max_number_of_winners: 1)
      end

      def pending_tie
        Budget::Result.new(budget.reload, heading).pending_tie
      end

      it "reports no tie before winners are calculated" do
        expect(pending_tie).to be nil
      end

      it "reports the tie once winners are calculated" do
        calculate

        expect(budget.reload.winners_tie_open).to be true
        expect(pending_tie).to be_present
      end

      it "records that no tie is open when the calculation ends without one" do
        budget.update!(max_number_of_winners: 2)

        calculate

        expect(budget.reload.winners_tie_open).to be false
        expect(pending_tie).to be nil
      end

      it "reports no tie once the tie is resolved" do
        calculate
        budget.update!(tie_resolved_at: budget.winners_calculated_at)

        expect(pending_tie).to be nil
      end

      it "reopens the tie when the resolution is older than the last calculation" do
        budget.update!(tie_resolved_at: 1.hour.ago)

        calculate

        expect(budget.reload.tie_resolved_at).to be < budget.winners_calculated_at
        expect(pending_tie).to be_present
      end
    end
  end
end
