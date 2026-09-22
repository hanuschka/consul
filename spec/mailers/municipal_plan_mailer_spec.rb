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

  def mail_host
    Rails.application.config.action_mailer.default_url_options[:host]
  end
end
