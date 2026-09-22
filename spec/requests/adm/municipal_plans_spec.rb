require "rails_helper"

describe "Vorhaben in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }
  let(:district) { create(:registered_address_district) }
  let(:other_district) { create(:registered_address_district) }
  let(:topic) { create(:municipal_plan_topic) }
  let(:plan) { create(:municipal_plan, responsible: officer) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def patch_plan(attributes)
    patch adm_municipal_plans_municipal_plan_path(plan), params: { municipal_plan: attributes }
  end

  describe "the Versionsnummer when a case worker saves" do
    it "stays put on a save that changes nothing" do
      expect { patch_plan(district_ids: plan.district_ids, topic_ids: plan.topic_ids) }
        .not_to change { plan.reload.version }
    end

    it "advances once when only the Ortsteile change" do
      expect { patch_plan(district_ids: plan.district_ids + [other_district.id]) }
        .to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "advances once when only the Themen change" do
      expect { patch_plan(topic_ids: plan.topic_ids + [topic.id]) }
        .to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "advances only once when an attribute and an association change together" do
      expect do
        patch_plan(contact_name: "Kai Ostermann", district_ids: plan.district_ids + [other_district.id])
      end.to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "stays put when unchanged links are resubmitted" do
      link = plan.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)

      expect do
        patch_plan(links_attributes: { "0" => { id: link.id, title: link.title, url: link.url,
                                                given_order: link.given_order }})
      end.not_to change { plan.reload.version }
    end

    it "advances once when a link is edited" do
      link = plan.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)

      expect do
        patch_plan(links_attributes: { "0" => { id: link.id, title: "Rahmenplan 2025",
                                                url: link.url, given_order: link.given_order }})
      end.to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "moves to 1.0 when the plan is released" do
      expect { patch release_adm_municipal_plans_municipal_plan_path(plan) }
        .to change { plan.reload.version }.from("0.1").to("1.0")
    end

    it "stays put when the released plan is archived" do
      patch release_adm_municipal_plans_municipal_plan_path(plan)

      expect { patch archive_adm_municipal_plans_municipal_plan_path(plan) }
        .not_to change { plan.reload.version }
    end
  end

  describe "an Entwurf that is still incomplete" do
    def create_plan(attributes)
      post adm_municipal_plans_municipal_plans_path,
           params: { municipal_plan: { status: "draft" }.merge(attributes) }
    end

    def missing_field_message(field)
      I18n.t("activerecord.errors.models.municipal_plan.release_required",
             field: MunicipalPlan.human_attribute_name(field))
    end

    it "saves with nothing but a Titel" do
      expect { create_plan(title: "Halbfertiges Vorhaben") }.to change(MunicipalPlan, :count).by(1)

      expect(MunicipalPlan.last.title).to eq("Halbfertiges Vorhaben")
    end

    it "refuses the submission and names every missing field" do
      create_plan(title: "Halbfertiges Vorhaben")

      patch submit_adm_municipal_plans_municipal_plan_path(MunicipalPlan.last)

      expect(MunicipalPlan.last.submitted_at).to be_nil
      expect(MunicipalPlan.last).to be_draft

      MunicipalPlan::RELEASE_REQUIRED_FIELDS.each do |field|
        expect(response.body).to include(missing_field_message(field))
      end
    end

    it "shows every value again when it is reopened" do
      create_plan(title: "Halbfertiges Vorhaben", short_description: "Nur ein Anfang",
                  contact_name: "Kai Ostermann",
                  district_ids: [district.id], topic_ids: [topic.id])

      get edit_adm_municipal_plans_municipal_plan_path(MunicipalPlan.last)

      expect(response.body).to include("Halbfertiges Vorhaben")
      expect(response.body).to include("Nur ein Anfang")
      expect(response.body).to include("Kai Ostermann")
      expect(response.body).to match(/value="#{district.id}"[^>]*checked/)
      expect(response.body).to match(/value="#{topic.id}"[^>]*checked/)
    end
  end

  describe "the release process" do
    let(:released) { create(:municipal_plan, :published, responsible: officer, version: "1.0") }

    it "sends an edit of a released Vorhaben to its working copy" do
      get edit_adm_municipal_plans_municipal_plan_path(released)

      copy = released.reload.working_copy

      expect(copy).to be_present
      expect(response).to redirect_to(edit_adm_municipal_plans_municipal_plan_path(copy))
    end

    it "refuses to write content straight onto a released Vorhaben" do
      patch adm_municipal_plans_municipal_plan_path(released),
            params: { municipal_plan: { short_description: "Direkt geändert" }}

      expect(released.reload.short_description).not_to eq("Direkt geändert")
      expect(response).to redirect_to(
        edit_adm_municipal_plans_municipal_plan_path(released.reload.working_copy)
      )
    end

    it "keeps working copies out of the Vorhaben list" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)

      get adm_municipal_plans_root_path

      expect(response.body).not_to include(
        adm_municipal_plans_municipal_plan_path(copy)
      )
    end

    it "refuses to hand in a copy that changes nothing" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)

      expect(::MunicipalPlans::SubmissionNotificationService).not_to receive(:call)

      patch submit_adm_municipal_plans_municipal_plan_path(copy)

      expect(copy.reload.submitted_at).to be_nil
      expect(flash[:alert])
        .to eq(I18n.t("adm.municipal_plans.municipal_plans.submit.no_changes"))
    end

    it "releases the copy onto the released Vorhaben" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)
      copy.update!(short_description: "Neue Fassung")

      patch release_adm_municipal_plans_municipal_plan_path(copy)

      expect(released.reload.short_description).to eq("Neue Fassung")
      expect(released.version).to eq("1.1")
      expect(response).to redirect_to(adm_municipal_plans_municipal_plan_path(released))
    end
  end

  describe "what a Sachbearbeitung may do" do
    let(:plan) { create(:municipal_plan, responsible: officer) }

    before { login_as(officer.user) }

    it "cannot release its own Vorhaben" do
      patch release_adm_municipal_plans_municipal_plan_path(plan)

      expect(plan.reload).to be_draft
      expect(response).to redirect_to(adm_root_path)
      expect(flash[:alert]).to eq(I18n.t("adm.not_authorized"))
    end

    it "cannot even reach another Vorhaben" do
      other = create(:municipal_plan, responsible: create(:municipal_plan_officer))

      expect { patch release_adm_municipal_plans_municipal_plan_path(other) }
        .to raise_error(ActiveRecord::RecordNotFound)

      expect(other.reload).to be_draft
    end

    it "can hand its own Vorhaben in" do
      patch submit_adm_municipal_plans_municipal_plan_path(plan)

      expect(plan.reload.submitted_at).to be_present
      expect(plan).to be_draft
    end

    it "notifies the administration when it hands a Vorhaben in" do
      expect(::MunicipalPlans::SubmissionNotificationService).to receive(:call)

      patch submit_adm_municipal_plans_municipal_plan_path(plan)
    end

    it "notifies nobody when the submission is refused" do
      incomplete = create(:municipal_plan, responsible: officer)
      incomplete.topic_assignments.destroy_all

      expect(::MunicipalPlans::SubmissionNotificationService).not_to receive(:call)

      patch submit_adm_municipal_plans_municipal_plan_path(incomplete)

      expect(incomplete.reload.submitted_at).to be_nil
    end

    it "can archive a released Vorhaben and take it back out without a release" do
      plan.update!(submitted_at: Time.current)
      ::MunicipalPlans::ReleaseService.call(plan)

      patch archive_adm_municipal_plans_municipal_plan_path(plan)
      expect(plan.reload.status).to eq("archived")

      expect { patch unarchive_adm_municipal_plans_municipal_plan_path(plan) }
        .not_to change { plan.reload.version }

      expect(plan.reload.status).to eq("published")
    end
  end

  describe "the release workflow on the detail page" do
    let(:released) { create(:municipal_plan, :published, responsible: officer, version: "1.0") }

    it "points an administrator at a pending version" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)

      get adm_municipal_plans_municipal_plan_path(released)

      expect(response.body).to include(
        I18n.t("adm.municipal_plans.municipal_plans.show.release_pending.title")
      )
      expect(response.body).to include(adm_municipal_plans_municipal_plan_path(copy))
    end

    it "shows what the pending version changes" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)
      copy.update!(contact_name: "Lena Wolf")

      get adm_municipal_plans_municipal_plan_path(copy)

      expect(response.body).to include(
        I18n.t("adm.municipal_plans.municipal_plans.show.changes.title")
      )
      expect(response.body).to include(MunicipalPlan.human_attribute_name(:contact_name))
      expect(response.body).to include("Lena Wolf")
      expect(response.body).to include(adm_municipal_plans_municipal_plan_path(released))
    end

    it "says so when the pending version changes nothing" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)

      get adm_municipal_plans_municipal_plan_path(copy)

      expect(response.body).to include(
        I18n.t("adm.municipal_plans.municipal_plans.show.changes.no_changes")
      )
    end

    it "offers the release action to an administrator" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)

      get adm_municipal_plans_municipal_plan_path(copy)

      expect(response.body).to include(release_adm_municipal_plans_municipal_plan_path(copy))
      expect(response.body).to include(
        I18n.t("adm.municipal_plans.municipal_plans.show.actions.release")
      )
    end

    it "offers archiving on a released Vorhaben" do
      get adm_municipal_plans_municipal_plan_path(released)

      expect(response.body).to include(archive_adm_municipal_plans_municipal_plan_path(released))
    end

    it "keeps the release action away from a Sachbearbeitung" do
      copy = ::MunicipalPlans::WorkingCopyService.call(released)
      login_as(officer.user)

      get adm_municipal_plans_municipal_plan_path(copy)

      expect(response.body).to include(submit_adm_municipal_plans_municipal_plan_path(copy))
      expect(response.body).not_to include(release_adm_municipal_plans_municipal_plan_path(copy))
    end

    it "no longer lets the form change the status" do
      get edit_adm_municipal_plans_municipal_plan_path(
        create(:municipal_plan, responsible: officer)
      )

      expect(response.body).not_to include("municipal_plan[status]")
    end
  end
end
