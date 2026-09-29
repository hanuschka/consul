require "rails_helper"

describe "Feasibility in the /adm investment form", type: :request do
  let(:admin) { create(:administrator).user }
  let(:investment) { create(:budget_investment) }
  let(:projekt_phase) { investment.budget.projekt_phase }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def save_feasibility(feasibility, valuation_finished:)
    patch adm_projekts_phase_budget_investment_path(projekt_phase, investment),
          params: {
            editor: "feasibility",
            budget_investment: {
              feasibility: feasibility,
              valuator_explanation: "Begründung",
              valuation_finished: valuation_finished ? "1" : "0"
            }
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "tells the author a proposal meets the criteria once the valuation is finished" do
    expect { save_feasibility("feasible", valuation_finished: true) }
      .to have_enqueued_mail(Mailer, :budget_investment_feasible)

    expect(investment.reload.email_on_feasibility_sent_at).to be_present
  end

  it "tells the author a proposal does not meet the criteria once the valuation is finished" do
    expect { save_feasibility("unfeasible", valuation_finished: true) }
      .to have_enqueued_mail(Mailer, :budget_investment_unfeasible)
  end

  it "sends nothing while the valuation is not finished" do
    expect { save_feasibility("feasible", valuation_finished: false) }.not_to have_enqueued_mail

    expect(investment.reload.email_on_feasibility_sent_at).to be_nil
  end

  it "sends nothing for a proposal that is still not evaluated" do
    expect { save_feasibility("undecided", valuation_finished: true) }.not_to have_enqueued_mail

    expect(investment.reload.email_on_feasibility_sent_at).to be_nil
  end

  it "sends the mail only once" do
    save_feasibility("feasible", valuation_finished: true)

    expect { save_feasibility("unfeasible", valuation_finished: true) }.not_to have_enqueued_mail
  end

  it "sends nothing when the valuator's form already sent it" do
    investment.update_column(:email_on_feasibility_sent_at, 1.day.ago)

    expect { save_feasibility("feasible", valuation_finished: true) }.not_to have_enqueued_mail
  end

  it "sends nothing when another editor saves a finished valuation" do
    investment.update_columns(feasibility: "feasible", valuation_finished: true)

    expect do
      patch adm_projekts_phase_budget_investment_path(projekt_phase, investment),
            params: { editor: "pricing", budget_investment: { price: 1000 }},
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end.not_to have_enqueued_mail
  end
end
