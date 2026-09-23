require "rails_helper"

describe "Converting a Vorhaben into a Beteiligungsprojekt", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) { create(:municipal_plan, :published, responsible: officer, title: "Stadtteilzentrum Lobeda") }
  let(:params) { { municipal_plan_projekt_conversion: { name: "Stadtteilzentrum Lobeda", subtitle: "Kurz" } } }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  describe "as the administration" do
    before { login_as(admin) }

    it "creates the project and returns to the Vorhaben" do
      expect { post adm_municipal_plans_municipal_plan_projekt_conversion_path(plan), params: params }
        .to change(Projekt, :count).by(1)

      expect(response).to redirect_to(adm_municipal_plans_municipal_plan_path(plan))
      expect(Projekt.last.municipal_plan).to eq plan
    end

    it "re-renders the form without creating anything when the title is blank" do
      plan
      params[:municipal_plan_projekt_conversion][:name] = ""

      expect { post adm_municipal_plans_municipal_plan_projekt_conversion_path(plan), params: params }
        .not_to change(Projekt, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "opens the form prefilled from the Vorhaben" do
      get new_adm_municipal_plans_municipal_plan_projekt_conversion_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Stadtteilzentrum Lobeda"')
    end

    it "offers the conversion on the Vorhaben page" do
      get adm_municipal_plans_municipal_plan_path(plan)

      expect(response.body).to include(new_adm_municipal_plans_municipal_plan_projekt_conversion_path(plan))
    end

    it "refuses to convert a Vorhaben still in Entwurf" do
      draft = create(:municipal_plan, responsible: officer)

      expect { post adm_municipal_plans_municipal_plan_projekt_conversion_path(draft), params: params }
        .not_to change(Projekt, :count)

      expect(response).to redirect_to(adm_root_path)
    end
  end

  describe "as a Sachbearbeitung" do
    before { login_as(officer.user) }

    it "sees no conversion action on the Vorhaben page" do
      get adm_municipal_plans_municipal_plan_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(new_adm_municipal_plans_municipal_plan_projekt_conversion_path(plan))
    end

    it "cannot open the conversion form directly" do
      get new_adm_municipal_plans_municipal_plan_projekt_conversion_path(plan)

      expect(response).to redirect_to(adm_root_path)
    end

    it "cannot convert by posting directly" do
      plan

      expect { post adm_municipal_plans_municipal_plan_projekt_conversion_path(plan), params: params }
        .not_to change(Projekt, :count)

      expect(response).to redirect_to(adm_root_path)
    end
  end
end
