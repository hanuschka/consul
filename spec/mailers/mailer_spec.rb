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

  describe "the hidden email" do
    let(:author) { create(:user, username: "Anna", locale: "de") }
    let(:proposal) { create(:proposal, author: author, title: "Mehr Bänke im Park") }

    it "uses the customized template" do
      SiteCustomization::EmailTemplate.create!(
        mailer_class: "Mailer",
        mailer_action: "resource_hidden",
        locale: "de",
        subject: "Ihr Beitrag wurde ausgeblendet",
        body: "<p>Guten Tag {{ username }}, {{ resource_text }}</p>"
      )

      email = Mailer.resource_hidden(proposal)

      expect(email.subject).to eq "Ihr Beitrag wurde ausgeblendet"
      expect(email.body.encoded).to include("Guten Tag Anna, Mehr Bänke im Park")
    end

    it "uses the default text otherwise" do
      email = Mailer.resource_hidden(proposal)

      expect(email.subject).to eq I18n.t("mailers.resource_hidden.subject", locale: :de)
      expect(email.body.encoded).to include("Hallo Anna,")
    end
  end

  describe "the formular answer created email" do
    let(:author) { create(:user, email: "anna@beispiel.de") }
    let(:formular) { Formular.create!(projekt_phase: create(:projekt_phase)) }

    def answer_with(email)
      field = formular.formular_fields.create!(name: "E-Mail", kind: "email", email_for_confirmation: "1")
      formular.formular_answers.create!(submitter_id: author.id, answers: { field.key => email })
    end

    it "is not sent when the confirmation email goes to the account address" do
      email = Mailer.formular_answer_created(answer_with(" Anna@Beispiel.de "))

      expect { email.deliver_now }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "is sent when the confirmation email goes to another address" do
      Mailer.formular_answer_created(answer_with("freund@beispiel.de")).deliver_now

      expect(ActionMailer::Base.deliveries.last.to).to eq ["anna@beispiel.de"]
    end
  end
end
