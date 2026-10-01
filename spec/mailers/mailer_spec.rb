require "rails_helper"

describe Mailer do
  describe "the investment link in customized feasibility emails" do
    let(:investment) { create(:budget_investment, valuator_explanation: "Begründung") }

    def customize(action)
      SiteCustomization::EmailTemplate.create!(
        projekt_phase: investment.budget.projekt_phase,
        mailer_class: "Mailer",
        mailer_action: action,
        locale: I18n.locale,
        subject: "Bürgerbudget",
        body: "<p>Link: {{ investment_url }}</p>"
      )
    end

    %w[budget_investment_feasible budget_investment_unfeasible].each do |action|
      it "fills investment_url in #{action}" do
        customize(action)

        email = Mailer.public_send(action, investment)

        investment_path = "/budgets/#{investment.budget.to_param}/investments/#{investment.to_param}"

        expect(email.body.encoded).to include(investment_path)
      end

      it "lists investment_url as an available variable for #{action}" do
        expect(SiteCustomization::EmailTemplate::EMAIL_TEMPLATES["Mailer##{action}"][:variables])
          .to include("investment_url")
      end
    end
  end
end
