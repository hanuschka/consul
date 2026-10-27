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
    phases = investment.budget.phases
    phases.where.not(kind: kind).update_all(enabled: false)
    phases.where(kind: kind).update_all(starts_at: 1.week.ago, ends_at: 1.week.from_now)
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

  def current_phase_with_price_phase_next(kind)
    phases = investment.budget.phases
    phases.update_all(enabled: false)
    phases.where(kind: kind).update_all(enabled: true, starts_at: 1.week.ago, ends_at: 1.day.from_now)
    phases.where(kind: "publishing_prices")
          .update_all(enabled: true, starts_at: 1.day.from_now, ends_at: 1.week.from_now)
  end

  def start_price_phase
    phases = investment.budget.phases
    phases.where(kind: "valuating").update_all(ends_at: 1.day.ago)
    phases.where(kind: "publishing_prices").update_all(starts_at: 1.day.ago)
  end

  def selection_inputs
    get adm_projekts_phase_budget_investment_path(projekt_phase, investment)

    Nokogiri::HTML(response.body).css('input[type="radio"][name="budget_investment[selected]"]')
  end

  it "keeps the selection locked during the support phase" do
    current_phase_with_price_phase_next("selecting")

    expect(selection_inputs).not_to be_empty
    expect(selection_inputs.map { |input| input["disabled"] }).to all(be_present)
  end

  context "during the valuation phase with the price phase enabled" do
    before { current_phase_with_price_phase_next("valuating") }

    it "lets admins set the selection" do
      expect(selection_inputs).not_to be_empty
      expect(selection_inputs.map { |input| input["disabled"] }).to all(be_nil)
    end

    it "lets a project manager set and save the selection" do
      manager = create(:projekt_manager)
      create(:projekt_manager_assignment, projekt: projekt_phase.projekt, projekt_manager: manager,
                                          permissions: ["manage"])
      login_as(manager.user)

      inputs = selection_inputs
      expect(inputs).not_to be_empty
      expect(inputs.map { |input| input["disabled"] }).to all(be_nil)

      save_selection(true)
      expect(investment.reload).to be_selected
    end

    it "lists the proposals admitted during valuation once the price phase starts" do
      not_admitted = create(:budget_investment, feasibility: "feasible", heading: investment.heading,
                                                title: "Not admitted fountain")
      inputs = selection_inputs
      expect(inputs).not_to be_empty
      expect(inputs.map { |input| input["disabled"] }).to all(be_nil)

      save_selection(true)
      start_price_phase
      investment.budget.update_columns(published: true, show_results_after_first_vote: true)

      login_as(create(:user))
      get projekt_phase_footer_tab_page_path(projekt_phase.projekt.page, projekt_phase, format: :js),
          xhr: true

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(investment.title)
      expect(response.body).not_to include(not_admitted.title)
    end

    it "saves the selection but keeps the mail back" do
      expect { save_selection(true) }.not_to have_enqueued_mail

      investment.reload
      expect(investment).to be_selected
      expect(investment).to be_selection_email_deferred
      expect(investment.email_on_selected_sent_at).to be_nil
    end

    it "does not send the kept-back mail before the price phase" do
      save_selection(true)

      expect { Budget.send_deferred_selection_emails }.not_to have_enqueued_mail
      expect(investment.reload).to be_selection_email_deferred
    end

    it "sends the final selection once the price phase has started" do
      save_selection(true)
      save_selection(false)
      start_price_phase

      expect { Budget.send_deferred_selection_emails }
        .to have_enqueued_mail(Mailer, :budget_investment_unselected)
      expect(investment.reload).not_to be_selection_email_deferred
      expect(investment.email_on_selected_sent_at).to be_present

      expect { Budget.send_deferred_selection_emails }.not_to have_enqueued_mail
    end

    it "keeps the mail back when a date gap makes a later phase look current" do
      save_selection(true)
      phases = investment.budget.phases
      phases.where(kind: "valuating").update_all(starts_at: 1.week.from_now, ends_at: 2.weeks.from_now)
      phases.where(kind: "publishing_prices")
            .update_all(starts_at: 2.weeks.from_now, ends_at: 3.weeks.from_now)
      phases.where(kind: "balloting")
            .update_all(enabled: true, starts_at: 3.weeks.from_now, ends_at: 4.weeks.from_now)
      expect(Budget.find(investment.budget_id).current_phase.kind).to eq "balloting"

      expect { Budget.send_deferred_selection_emails }.not_to have_enqueued_mail
      expect(investment.reload).to be_selection_email_deferred
    end

    it "skips a kept-back proposal whose budget is gone" do
      save_selection(true)
      start_price_phase
      orphan = create(:budget_investment, feasibility: "feasible")
      orphan.update_columns(budget_id: 0, selection_email_deferred: true)

      expect { Budget.send_deferred_selection_emails }
        .to have_enqueued_mail(Mailer, :budget_investment_selected).once
    end

    it "sends the mail right away when the selection is saved again in the price phase" do
      save_selection(true)
      start_price_phase

      expect { save_selection(true) }.to have_enqueued_mail(Mailer, :budget_investment_selected)
      expect { Budget.send_deferred_selection_emails }.not_to have_enqueued_mail
    end
  end

  it "sends nothing when another editor is saved" do
    patch adm_projekts_phase_budget_investment_path(projekt_phase, investment),
          params: { editor: "pricing", budget_investment: { price: 1000 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(investment.reload.email_on_selected_sent_at).to be_nil
  end
end
