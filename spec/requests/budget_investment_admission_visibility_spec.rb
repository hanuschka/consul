require "rails_helper"

describe "Admission on the public investment page", type: :request do
  let(:investment) { create(:budget_investment, feasibility: "feasible", selected: true) }
  let(:budget) { investment.budget }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    budget.update_column(:published, true)

    phases = budget.phases
    phases.update_all(enabled: false)
    phases.where(kind: "valuating").update_all(enabled: true, starts_at: 1.week.ago, ends_at: 1.day.from_now)
    phases.where(kind: "publishing_prices")
          .update_all(enabled: true, starts_at: 1.day.from_now, ends_at: 1.week.from_now)
  end

  def start_price_phase
    budget.phases.where(kind: "valuating").update_all(ends_at: 1.day.ago)
    budget.phases.where(kind: "publishing_prices").update_all(starts_at: 1.day.ago)
  end

  def admission_notes
    %i[de en].map do |locale|
      note = I18n.t("budgets.investments.show.project_selected", locale: locale)
      ActionView::Base.full_sanitizer.sanitize(note)
    end
  end

  def shows_admission?
    get budget_investment_path(budget, investment)
    expect(response).to have_http_status(:ok)

    text = ActionView::Base.full_sanitizer.sanitize(response.body)
    admission_notes.any? { |note| text.include?(note) }
  end

  it "hides an admission made during the valuation phase" do
    expect(shows_admission?).to be false
  end

  it "shows the admission once the price phase has started" do
    start_price_phase

    expect(shows_admission?).to be true
  end
end
