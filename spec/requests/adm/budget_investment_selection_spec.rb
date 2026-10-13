require "rails_helper"

describe "Selection in the /adm investment form", type: :request do
  let(:admin) { create(:administrator).user }
  let(:investment) { create(:budget_investment, feasibility: "feasible") }
  let(:projekt_phase) { investment.budget.projekt_phase }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    current_budget_phase("publishing_prices")
    login_as(admin)
  end

  def current_budget_phase(kind)
    investment.budget.phases.where.not(kind: kind).update_all(enabled: false)
  end

  def save_selection(selected)
    patch adm_projekts_phase_budget_investment_path(projekt_phase, investment),
          params: { editor: "selection", budget_investment: { selected: selected.to_s } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "tells the author a proposal was selected for the final vote" do
    expect { save_selection(true) }.to have_enqueued_mail(Mailer, :budget_investment_selected)

    expect(investment.reload).to be_selected
    expect(investment.email_on_selected_sent_at).to be_present
  end

  it "tells the author a proposal was not selected" do
    investment.update_column(:selected, true)

    expect { save_selection(false) }.to have_enqueued_mail(Mailer, :budget_investment_unselected)

    expect(investment.reload).not_to be_selected
    expect(investment.email_on_selected_sent_at).to be_present
  end

  it "tells the author when an untouched proposal is saved as not selected" do
    expect { save_selection(false) }.to have_enqueued_mail(Mailer, :budget_investment_unselected)
  end

  it "sends nothing when the same selection is saved again" do
    save_selection(true)

    expect { save_selection(true) }.not_to have_enqueued_mail
  end

  it "sends nothing when the selection is changed after the mail went out" do
    save_selection(true)

    expect { save_selection(false) }.not_to have_enqueued_mail
  end

  it "sends nothing when the valuator's form already sent it" do
    investment.update_column(:email_on_selected_sent_at, 1.day.ago)

    expect { save_selection(true) }.not_to have_enqueued_mail
  end

  %w[unfeasible undecided].each do |feasibility|
    it "sends nothing for an #{feasibility} proposal and keeps the mail pending" do
      investment.update_column(:feasibility, feasibility)

      expect { save_selection(false) }.not_to have_enqueued_mail

      expect(investment.reload.email_on_selected_sent_at).to be_nil
    end
  end

  it "sends the mail once a pending proposal becomes feasible" do
    investment.update_column(:feasibility, "undecided")
    save_selection(true)
    investment.update_column(:feasibility, "feasible")

    expect { save_selection(true) }.to have_enqueued_mail(Mailer, :budget_investment_selected)
  end

  it "still tells the author while the voting is running" do
    investment.budget.phases.update_all(enabled: true)
    current_budget_phase("balloting")

    expect { save_selection(true) }.to have_enqueued_mail(Mailer, :budget_investment_selected)
  end

  %w[reviewing_ballots finished].each do |kind|
    it "sends nothing once the voting has ended (#{kind})" do
      investment.budget.phases.update_all(enabled: true)
      current_budget_phase(kind)

      expect { save_selection(true) }.not_to have_enqueued_mail

      expect(investment.reload.email_on_selected_sent_at).to be_nil
    end
  end

  it "sends nothing when another editor is saved" do
    patch adm_projekts_phase_budget_investment_path(projekt_phase, investment),
          params: { editor: "pricing", budget_investment: { price: 1000 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(investment.reload.email_on_selected_sent_at).to be_nil
  end
end
