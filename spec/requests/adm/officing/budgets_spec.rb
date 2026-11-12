require "rails_helper"

describe "Adm officing budget desk", type: :request do
  let(:budget) { create(:budget, :with_heading) }
  let(:officer) { create(:administrator).user }
  let(:offline_user) { create(:user) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)

    allow_any_instance_of(ProjektPhase::BudgetPhase).to receive(:permission_problem).and_return(nil)

    officing_manager = OfficingManager.create!(user: officer)
    OfficingManagerAssignment.create!(officing_manager: officing_manager, projekt_phase: budget.projekt_phase)

    login_as(officer)
  end

  def current_budget_phase(kind)
    budget.phases.where.not(kind: kind).update_all(enabled: false)
    budget.phases.where(kind: kind).update_all(enabled: true, starts_at: 1.week.ago, ends_at: 1.week.from_now)
  end

  def create_investments(count, **attributes)
    create_list(:budget_investment, count, heading: budget.heading, feasibility: "feasible", **attributes)
  end

  def open_desk
    get officing_desk_adm_officing_budget_path(budget, offline_user_id: offline_user.id)
  end

  def listed_ids
    response.body.scan(/Investment \d+ #(\d+)/).flatten.map(&:to_i)
  end

  describe "while balloting" do
    before { current_budget_phase("balloting") }

    it "lists every selected investment on one page" do
      investments = create_investments(34, selected: true)

      open_desk

      expect(response).to have_http_status(:ok)
      expect(listed_ids).to match_array investments.map(&:id)
      expect(response.body).not_to include("pagy")
    end

    it "lists the investments by their number" do
      investments = create_investments(5, selected: true)
      investments.first.update_column(:price, 1)

      open_desk

      expect(listed_ids).to eq investments.map(&:id).sort
    end
  end

  describe "while selecting" do
    before { current_budget_phase("selecting") }

    it "marks the investment the voter already supports" do
      supported, *others = create_investments(3)
      supported.vote_by(voter: offline_user, vote: "yes")

      open_desk

      expect(response.body.scan(I18n.t("adm.officing.budgets.investment_vote.revoke")).size).to eq 1
      expect(response.body.scan(I18n.t("adm.officing.budgets.investment_vote.support")).size).to eq others.size
    end

    it "shows the weight of a distributed vote" do
      budget.update!(voting_style: "distributed")
      supported = create_investments(1).first
      supported.vote_by(voter: offline_user, vote: "yes", vote_weight: 3)

      open_desk

      expect(response.body).to include(I18n.t("adm.officing.budgets.investment_vote.weight", count: 3))
    end
  end
end
