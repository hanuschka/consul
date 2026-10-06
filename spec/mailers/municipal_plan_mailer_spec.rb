require "rails_helper"

describe MunicipalPlanMailer do
  let(:officer) { create(:municipal_plan_officer) }
  let(:administrator) { create(:administrator) }
  let(:plan) do
    create(:municipal_plan, responsible: officer, title: "Sanierung der Brücke am Markt")
  end

  before { ActionMailer::Base.deliveries.clear }

  describe "submitted_for_release" do
    let(:mail) { MunicipalPlanMailer.submitted_for_release(plan, administrator) }

    it "goes to the administrator and names the Vorhaben" do
      expect(mail.to).to eq([administrator.email])
      expect(mail.subject).to include("Sanierung der Brücke am Markt")
    end

    it "names the Zuständigkeit and links to the review page" do
      expect(mail.body.encoded).to include(officer.name)
      expect(mail.body.encoded)
        .to include(adm_municipal_plans_municipal_plan_url(plan, host: mail_host))
    end

    it "manages without a Zuständigkeit" do
      plan.update_columns(responsible_type: nil, responsible_id: nil)

      expect { MunicipalPlanMailer.submitted_for_release(plan.reload, administrator).deliver_now }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "sends nothing to an administrator without an address" do
      administrator.user.update_columns(email: nil)

      expect { MunicipalPlanMailer.submitted_for_release(plan, administrator.reload).deliver_now }
        .not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  describe "notice_submitted" do
    let(:notice) do
      plan.notices.create!(name: "Kai Ostermann", email: "kai@example.org",
                           body: "Bitte prüfen Sie den Zeitplan.")
    end
    let(:mail) { MunicipalPlanMailer.notice_submitted(notice, "amt@jena.example") }

    it "names the Vorhaben in the subject" do
      expect(mail.to).to eq(["amt@jena.example"])
      expect(mail.subject).to include("Sanierung der Brücke am Markt")
    end

    it "links to the Vorhaben and carries the Hinweis with its sender" do
      expect(mail.body.encoded).to include(municipal_plan_url(plan, host: mail_host))
      expect(mail.body.encoded).to include("Kai Ostermann")
      expect(mail.body.encoded).to include("kai@example.org")
      expect(mail.body.encoded).to include("Bitte")
    end

    it "manages a Hinweis without a Name" do
      anonymous = plan.notices.create!(email: "kai@example.org", body: "Anonym")

      expect { MunicipalPlanMailer.notice_submitted(anonymous, "amt@jena.example").deliver_now }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "sends nothing without a recipient" do
      expect { MunicipalPlanMailer.notice_submitted(notice, "").deliver_now }
        .not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  def mail_host
    Rails.application.config.action_mailer.default_url_options[:host]
  end
end
