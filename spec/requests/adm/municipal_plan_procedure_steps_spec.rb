require "rails_helper"

describe "Verfahrensschritte in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    set_setting("municipal_plans.procedure_steps", true)
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def listed_names
    page.css("tr[data-sortable-id] th[data-field='name']").map { |cell| cell.text.strip }
  end

  def menu_entry
    page.at_css("a.nav-item-link[href='#{adm_municipal_plans_procedure_steps_path}']")
  end

  def destroy_message(key)
    I18n.t("adm.municipal_plans.procedure_steps.destroy.#{key}")
  end

  describe "as an administrator" do
    before { login_as(admin) }

    it "lists the steps in their order" do
      first = create(:municipal_plan_procedure_step, name: "1.0 Einleitungsbeschluss")
      second = create(:municipal_plan_procedure_step, name: "2.0 Frühzeitige Unterrichtung")
      third = create(:municipal_plan_procedure_step, name: "3.0 Entwurf")
      MunicipalPlan::ProcedureStep.order_procedure_steps([third.id, first.id, second.id])

      get adm_municipal_plans_procedure_steps_path

      expect(response).to have_http_status(:ok)
      expect(listed_names).to eq ["3.0 Entwurf", "1.0 Einleitungsbeschluss", "2.0 Frühzeitige Unterrichtung"]
      expect(menu_entry).to be_present
    end

    it "creates a step" do
      get new_adm_municipal_plans_procedure_step_path
      expect(response).to have_http_status(:ok)

      post adm_municipal_plans_procedure_steps_path,
           params: { municipal_plan_procedure_step: { name: "4.0 Satzungsbeschluss" }}

      expect(response).to redirect_to(adm_municipal_plans_procedure_steps_path)
      expect(MunicipalPlan::ProcedureStep.last.name).to eq "4.0 Satzungsbeschluss"
    end

    it "refuses a step without a name" do
      expect do
        post adm_municipal_plans_procedure_steps_path, params: { municipal_plan_procedure_step: { name: "" }}
      end.not_to change { MunicipalPlan::ProcedureStep.count }

      expect(response).to have_http_status(:ok)
      expect(page.at_css("input[name='municipal_plan_procedure_step[name]']")).to be_present
    end

    it "edits a step" do
      step = create(:municipal_plan_procedure_step, name: "2.0 Frühzeitige Unterrichtung")

      get edit_adm_municipal_plans_procedure_step_path(step)
      expect(page.at_css("input[name='municipal_plan_procedure_step[name]']")["value"])
        .to eq "2.0 Frühzeitige Unterrichtung"

      patch adm_municipal_plans_procedure_step_path(step),
            params: { municipal_plan_procedure_step: { name: "2.0 Frühzeitige Beteiligung" }}

      expect(response).to redirect_to(adm_municipal_plans_procedure_steps_path)
      expect(step.reload.name).to eq "2.0 Frühzeitige Beteiligung"
    end

    it "reorders the steps" do
      first = create(:municipal_plan_procedure_step)
      second = create(:municipal_plan_procedure_step)

      patch order_procedure_steps_adm_municipal_plans_procedure_steps_path,
            params: { tree: [{ id: second.id }, { id: first.id }] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(MunicipalPlan::ProcedureStep.all).to eq [second, first]
    end

    it "deletes a step no Vorhaben uses" do
      step = create(:municipal_plan_procedure_step)

      delete adm_municipal_plans_procedure_step_path(step)

      expect(response).to redirect_to(adm_municipal_plans_procedure_steps_path)
      expect(flash[:notice]).to eq destroy_message(:success)
      expect(MunicipalPlan::ProcedureStep.exists?(step.id)).to be false
    end

    it "refuses to delete a step a Vorhaben uses" do
      step = create(:municipal_plan_procedure_step)
      create(:municipal_plan, procedure_step: step)

      delete adm_municipal_plans_procedure_step_path(step)

      expect(response).to redirect_to(adm_municipal_plans_procedure_steps_path)
      expect(flash[:alert]).to eq destroy_message(:cannot_destroy)
      expect(MunicipalPlan::ProcedureStep.exists?(step.id)).to be true
    end

    it "links the empty Verfahrensschritt choice of the Vorhaben form to this page" do
      get new_adm_municipal_plans_municipal_plan_path

      hint = page.at_css("#municipal_plan_procedure_step_id_hint")
      expect(hint.text)
        .to include I18n.t("adm.municipal_plans.municipal_plans.form_fields.no_procedure_steps")
      expect(hint.at_css("a[href='#{adm_municipal_plans_procedure_steps_path}']")).to be_present
    end
  end

  describe "when the setting is off" do
    let!(:step) { create(:municipal_plan_procedure_step) }

    before do
      set_setting("municipal_plans.procedure_steps", false)
      login_as(admin)
    end

    it "makes every page unavailable" do
      get adm_municipal_plans_procedure_steps_path
      expect(response).to have_http_status(:not_found)

      get new_adm_municipal_plans_procedure_step_path
      expect(response).to have_http_status(:not_found)

      get edit_adm_municipal_plans_procedure_step_path(step)
      expect(response).to have_http_status(:not_found)
    end

    it "changes nothing" do
      other = create(:municipal_plan_procedure_step)

      post adm_municipal_plans_procedure_steps_path, params: { municipal_plan_procedure_step: { name: "Neu" }}
      expect(response).to have_http_status(:not_found)

      patch adm_municipal_plans_procedure_step_path(step),
            params: { municipal_plan_procedure_step: { name: "Neu" }}
      expect(response).to have_http_status(:not_found)

      patch order_procedure_steps_adm_municipal_plans_procedure_steps_path,
            params: { tree: [{ id: other.id }, { id: step.id }] }, as: :json
      expect(response).to have_http_status(:not_found)

      delete adm_municipal_plans_procedure_step_path(other)
      expect(response).to have_http_status(:not_found)

      expect(MunicipalPlan::ProcedureStep.all).to eq [step, other]
      expect(step.reload.name).not_to eq "Neu"
    end

    it "hides the menu entry" do
      get adm_municipal_plans_topics_path

      expect(response).to have_http_status(:ok)
      expect(menu_entry).to be_nil
    end
  end

  describe "permissions, the same as for the Themen" do
    let(:step) { create(:municipal_plan_procedure_step) }

    it "turns a case worker away like from the Themen" do
      login_as(officer.user)

      get adm_municipal_plans_topics_path
      expect(response).to redirect_to(adm_root_path)

      get adm_municipal_plans_procedure_steps_path
      expect(response).to redirect_to(adm_root_path)

      get edit_adm_municipal_plans_procedure_step_path(step)
      expect(response).to redirect_to(adm_root_path)

      expect do
        post adm_municipal_plans_procedure_steps_path,
             params: { municipal_plan_procedure_step: { name: "Neu" }}
      end.not_to change { MunicipalPlan::ProcedureStep.count }

      delete adm_municipal_plans_procedure_step_path(step)
      expect(MunicipalPlan::ProcedureStep.exists?(step.id)).to be true
    end

    it "keeps the reordering from a case worker" do
      first = create(:municipal_plan_procedure_step)
      second = create(:municipal_plan_procedure_step)
      login_as(officer.user)

      patch order_procedure_steps_adm_municipal_plans_procedure_steps_path,
            params: { tree: [{ id: second.id }, { id: first.id }] }, as: :json

      expect(MunicipalPlan::ProcedureStep.all).to eq [first, second]
    end

    it "hides the menu entry and the form link from a case worker" do
      login_as(officer.user)

      get new_adm_municipal_plans_municipal_plan_path

      expect(response).to have_http_status(:ok)
      expect(menu_entry).to be_nil
      expect(page.at_css("#municipal_plan_procedure_step_id_hint a")).to be_nil
    end

    it "turns a user without a role away like from the Themen" do
      login_as(create(:user))

      get adm_municipal_plans_topics_path
      topics_response = response.status

      get adm_municipal_plans_procedure_steps_path

      expect(response.status).to eq topics_response
      expect(response).not_to have_http_status(:ok)
    end
  end
end
