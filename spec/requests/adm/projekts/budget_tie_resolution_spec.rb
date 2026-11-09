require "rails_helper"

describe "Resolving a tie between budget investments in /adm", type: :request do
  let(:budget) { create(:budget, :with_heading, hide_money: true, max_number_of_winners: 1) }
  let(:projekt_phase) { budget.projekt_phase }
  let!(:tied) do
    Array.new(2) do
      create(:budget_investment, heading: budget.heading, feasibility: "feasible", selected: true,
                                 ballot_lines_count: 40)
    end
  end

  let(:winners_calculated) { true }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Budget::Result.new(budget, budget.heading).calculate_winners if winners_calculated
  end

  def current_budget_phase(kind)
    budget.phases.where.not(kind: kind).update_all(enabled: false)
    budget.phases.where(kind: kind).update_all(starts_at: 1.week.ago, ends_at: 1.week.from_now)
  end

  def resolve_tie(picked)
    put resolve_tie_adm_projekts_phase_budget_path(projekt_phase, budget),
        params: { investment_ids: picked.map(&:id) }
  end

  context "as an administrator" do
    before { login_as(create(:administrator).user) }

    context "before winners are calculated" do
      let(:winners_calculated) { false }

      it "calculates the winners within the request" do
        current_budget_phase("finished")
        budget.update!(max_number_of_winners: 2)

        put calculate_winners_adm_projekts_phase_budget_path(projekt_phase, budget)

        expect(response).to redirect_to budget_investments_adm_projekts_phase_path(projekt_phase)
        expect(Budget::Investment.where(winner: true)).to match_array tied
        expect(budget.reload.winners_calculated_at).to be_present
      end
    end

    describe "the tie notice on the investments page" do
      let(:resolve_path) { resolve_tie_adm_projekts_phase_budget_path(projekt_phase, budget) }

      it "offers only recalculating once winners are calculated, reloading the whole page" do
        current_budget_phase("finished")

        get budget_investments_adm_projekts_phase_path(projekt_phase)
        page = Capybara.string(response.body)

        recalculate_path = recalculate_winners_adm_projekts_phase_budget_path(projekt_phase, budget)
        expect(page).to have_css("a[href='#{recalculate_path}'][data-turbo-frame='_top']")
        expect(page).not_to have_css("a[href='#{calculate_winners_adm_projekts_phase_budget_path(projekt_phase, budget)}']")
      end

      def notice_shown?
        get budget_investments_adm_projekts_phase_path(projekt_phase)
        Capybara.string(response.body).has_css?("form[action='#{resolve_path}']")
      end

      it "is shown with the tied investments once balloting is finished" do
        current_budget_phase("finished")

        expect(notice_shown?).to be true
        tied.each do |investment|
          expect(response.body).to include("value=\"#{investment.id}\"")
        end
      end

      context "before winners are calculated" do
        let(:winners_calculated) { false }

        it "is not shown" do
          current_budget_phase("finished")

          expect(notice_shown?).to be false
        end

        it "offers only calculating, reloading the whole page" do
          current_budget_phase("finished")

          get budget_investments_adm_projekts_phase_path(projekt_phase)
          page = Capybara.string(response.body)

          calculate_path = calculate_winners_adm_projekts_phase_budget_path(projekt_phase, budget)
          expect(page).to have_css("a[href='#{calculate_path}'][data-turbo-frame='_top']")
          expect(page).not_to have_css("a[href='#{recalculate_winners_adm_projekts_phase_budget_path(projekt_phase, budget)}']")
        end
      end

      it "is not shown while balloting is still open" do
        current_budget_phase("balloting")

        expect(notice_shown?).to be false
      end

      it "is not shown once the tie is resolved" do
        current_budget_phase("finished")
        resolve_tie([tied.first])

        expect(notice_shown?).to be false
      end
    end

    it "marks the picked investment as winner once balloting is finished" do
      current_budget_phase("finished")

      resolve_tie([tied.first])

      expect(response).to redirect_to budget_investments_adm_projekts_phase_path(projekt_phase)
      expect(flash[:notice]).to be_present
      expect(tied.first.reload).to be_winner
      expect(tied.last.reload).not_to be_winner
      expect(budget.reload.tie_resolved_at).to be_present
    end

    it "keeps the tie open when the selection does not fit" do
      current_budget_phase("finished")

      resolve_tie(tied)

      expect(flash[:alert]).to be_present
      expect(Budget::Investment.where(winner: true)).to be_empty
      expect(budget.reload.tie_resolved_at).to be nil
    end

    it "does not resolve the tie while balloting is still open" do
      current_budget_phase("balloting")

      resolve_tie([tied.first])

      expect(tied.first.reload).not_to be_winner
      expect(budget.reload.tie_resolved_at).to be nil
    end
  end

  it "does not let users without budget permissions resolve the tie" do
    current_budget_phase("finished")
    login_as(create(:user))

    resolve_tie([tied.first])

    expect(tied.first.reload).not_to be_winner
    expect(budget.reload.tie_resolved_at).to be nil
  end
end
