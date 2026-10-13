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

  describe "the selection emails" do
    let(:author) { create(:user, username: "Anna", locale: "de") }
    let(:investment) { create(:budget_investment, author: author, feasibility: "feasible") }

    %w[budget_investment_selected budget_investment_unselected].each do |action|
      it "uses the template customized for the budget phase in #{action}" do
        SiteCustomization::EmailTemplate.create!(
          projekt_phase: investment.budget.projekt_phase,
          mailer_class: "Mailer",
          mailer_action: action,
          locale: "de",
          subject: "Neuigkeiten zu Ihrem Vorschlag",
          body: "<p>Guten Tag {{ username }}</p>"
        )

        email = Mailer.public_send(action, investment)

        expect(email.subject).to eq "Neuigkeiten zu Ihrem Vorschlag"
        expect(email.body.encoded).to include("Guten Tag Anna")
      end

      it "greets in German with the default text in #{action}" do
        email = Mailer.public_send(action, investment)

        expect(email.subject).to eq I18n.t("mailers.#{action}.subject", locale: :de)
        expect(email.body.encoded).to include("Hallo Anna,")
        expect(email.body.encoded).not_to include("Hello")
      end
    end
  end
end
