require "rails_helper"

describe "Hinweise zu einem Vorhaben", type: :request do
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) do
    create(:municipal_plan, :published, responsible: officer,
                                        title: "Weiterentwicklung des Eichplatz-Areals")
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(Setting).to receive(:[]).and_call_original
    allow(Setting).to receive(:[]).with("process.municipal_plans").and_return(true)
  end

  def submit(attributes)
    post municipal_plan_notices_path(plan), params: { municipal_plan_notice: attributes }
  end

  describe "submitting one" do
    it "stores the Hinweis at its Vorhaben" do
      expect do
        submit(name: "Kai Ostermann", email: "kai@example.org", body: "Bitte prüfen Sie den Zeitplan.")
      end.to change { plan.notices.count }.by(1)

      notice = plan.notices.last

      expect(notice.name).to eq("Kai Ostermann")
      expect(notice.email).to eq("kai@example.org")
      expect(notice.body).to eq("Bitte prüfen Sie den Zeitplan.")
      expect(response).to redirect_to(municipal_plan_path(plan))
    end

    it "notifies the responsible department" do
      expect(::MunicipalPlans::NoticeNotificationService).to receive(:call)

      submit(email: "kai@example.org", body: "Eine Frage")
    end

    it "takes a Hinweis without a Name" do
      expect { submit(email: "kai@example.org", body: "Anonym") }
        .to change { plan.notices.count }.by(1)
    end
  end

  describe "a refused submission" do
    it "keeps the entered text and names the missing field" do
      expect { submit(name: "Kai Ostermann", email: "", body: "Bitte prüfen Sie den Zeitplan.") }
        .not_to change { plan.notices.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Bitte prüfen Sie den Zeitplan.")
      expect(response.body).to include("Kai Ostermann")
      expect(response.body).to include(MunicipalPlan::Notice.human_attribute_name(:email))
    end

    it "refuses a Hinweis longer than the limit" do
      expect { submit(email: "kai@example.org", body: "a" * (MunicipalPlan::Notice::MAX_BODY_LENGTH + 1)) }
        .not_to change { plan.notices.count }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "refuses an address that is not one" do
      expect { submit(email: "keine-adresse", body: "Eine Frage") }
        .not_to change { plan.notices.count }
    end

    it "notifies nobody" do
      expect(::MunicipalPlans::NoticeNotificationService).not_to receive(:call)

      submit(email: "", body: "")
    end

    it "swallows a submission that fills the honeypot" do
      expect do
        post municipal_plan_notices_path(plan),
             params: { municipal_plan_notice: { email: "kai@example.org", body: "Werbung",
                                                subtitle: "ich bin ein Bot" }}
      end.not_to change { plan.notices.count }
    end
  end

  describe "which Vorhaben take Hinweise" do
    it "refuses one on an Entwurf" do
      draft = create(:municipal_plan, responsible: officer)

      expect do
        post municipal_plan_notices_path(draft),
             params: { municipal_plan_notice: { email: "kai@example.org", body: "Eine Frage" }}
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "refuses one on an archived Vorhaben" do
      archived = create(:municipal_plan, :published, responsible: officer)
      archived.update!(status: "archived")

      expect do
        post municipal_plan_notices_path(archived),
             params: { municipal_plan_notice: { email: "kai@example.org", body: "Eine Frage" }}
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "is unreachable while the module is off" do
      allow(Setting).to receive(:[]).with("process.municipal_plans").and_return(nil)

      expect { submit(email: "kai@example.org", body: "Eine Frage") }
        .to raise_error(FeatureFlags::FeatureDisabled)
    end
  end

  describe "the form on the public page" do
    it "appears on a published Vorhaben" do
      get municipal_plan_path(plan)

      expect(response.body).to include(municipal_plan_notices_path(plan))
      expect(response.body).to include(I18n.t("custom.municipal_plans.notices.form.title"))
    end

    it "never shows the Hinweise that were submitted" do
      plan.notices.create!(name: "Kai Ostermann", email: "kai@example.org",
                           body: "Ein interner Hinweis")

      get municipal_plan_path(plan)

      expect(response.body).not_to include("Ein interner Hinweis")
      expect(response.body).not_to include("kai@example.org")
      expect(response.body).not_to include("Kai Ostermann")
    end
  end
end
