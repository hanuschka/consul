require "rails_helper"

describe Adm::DeficiencyReports::SubcategoriesController do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:category) { create(:deficiency_report_category) }

  context "as a deficiency report manager" do
    before { sign_in manager }

    describe "GET #index" do
      it "responds successfully" do
        create(:deficiency_report_subcategory, category: category)

        get :index, params: { category_id: category.id }

        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST #create" do
      it "creates a subcategory under its category" do
        expect do
          post :create, params: { category_id: category.id,
                                  deficiency_report_subcategory: { name: "Schlaglöcher" }}
        end.to change(DeficiencyReport::Subcategory, :count).by(1)

        subcategory = DeficiencyReport::Subcategory.last
        expect(subcategory.name).to eq("Schlaglöcher")
        expect(subcategory.category).to eq(category)
        expect(response).to redirect_to(adm_deficiency_reports_category_subcategories_path(category))
      end

      it "stores the AI hint" do
        post :create, params: { category_id: category.id,
                                deficiency_report_subcategory: { name: "Schlaglöcher",
                                                                 ai_hint: "Nur Fahrbahn, keine Gehwege" }}

        expect(DeficiencyReport::Subcategory.last.ai_hint).to eq("Nur Fahrbahn, keine Gehwege")
      end

      # Each subcategory carries its own default responsibility — the point of the taxonomy.
      it "assigns an officer group as default responsible" do
        group = create(:deficiency_report_officer_group)

        post :create, params: { category_id: category.id,
                                deficiency_report_subcategory: { name: "Schlaglöcher" },
                                default_responsible: "OfficerGroup:#{group.id}" }

        expect(DeficiencyReport::Subcategory.last.default_responsible).to eq(group)
      end

      it "assigns an individual officer as default responsible" do
        officer = create(:deficiency_report_officer)

        post :create, params: { category_id: category.id,
                                deficiency_report_subcategory: { name: "Schlaglöcher" },
                                default_responsible: "Officer:#{officer.id}" }

        expect(DeficiencyReport::Subcategory.last.default_responsible).to eq(officer)
      end

      it "leaves the responsibility empty when none is picked" do
        post :create, params: { category_id: category.id,
                                deficiency_report_subcategory: { name: "Schlaglöcher" },
                                default_responsible: "" }

        expect(DeficiencyReport::Subcategory.last.default_responsible).to be_nil
      end

      it "re-renders the form when the name is missing" do
        expect do
          post :create, params: { category_id: category.id,
                                  deficiency_report_subcategory: { name: "" }}
        end.not_to change(DeficiencyReport::Subcategory, :count)

        # A re-render answers 200, where a successful create redirects.
        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH #update" do
      let(:subcategory) { create(:deficiency_report_subcategory, category: category, name: "Alt") }

      it "renames the subcategory" do
        patch :update, params: { category_id: category.id, id: subcategory.id,
                                 deficiency_report_subcategory: { name: "Neu" }}

        expect(subcategory.reload.name).to eq("Neu")
        expect(response).to redirect_to(adm_deficiency_reports_category_subcategories_path(category))
      end

      it "re-renders the form when the name is cleared" do
        patch :update, params: { category_id: category.id, id: subcategory.id,
                                 deficiency_report_subcategory: { name: "" }}

        expect(response).to have_http_status(:ok)
        expect(subcategory.reload.name).to eq("Alt")
      end
    end

    describe "DELETE #destroy" do
      it "deletes an unused subcategory" do
        subcategory = create(:deficiency_report_subcategory, category: category)

        expect do
          delete :destroy, params: { category_id: category.id, id: subcategory.id }
        end.to change(DeficiencyReport::Subcategory, :count).by(-1)

        expect(flash[:notice]).to be_present
      end

      it "refuses to delete a subcategory a report still uses" do
        subcategory = create(:deficiency_report_subcategory, category: category)
        create(:deficiency_report, category: category, subcategory: subcategory)

        expect do
          delete :destroy, params: { category_id: category.id, id: subcategory.id }
        end.not_to change(DeficiencyReport::Subcategory, :count)

        expect(flash[:alert]).to be_present
      end
    end

    describe "PATCH #order_subcategories" do
      it "renumbers the subcategories from the submitted tree" do
        first = create(:deficiency_report_subcategory, category: category, given_order: 1)
        second = create(:deficiency_report_subcategory, category: category, given_order: 2)

        patch :order_subcategories, params: { category_id: category.id,
                                              tree: [{ id: second.id }, { id: first.id }] }

        expect(response).to have_http_status(:ok)
        expect(second.reload.given_order).to eq(1)
        expect(first.reload.given_order).to eq(2)
      end
    end
  end

  context "as an officer without manage_all" do
    let(:officer) { create(:deficiency_report_officer) }

    before { sign_in officer.user }

    # policy_scope alone does not gate the action — its Scope resolves to all — so index has to
    # authorize as well, or the taxonomy is readable by any officer.
    it "refuses to read the subcategory list" do
      get :index, params: { category_id: category.id }

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
      expect(flash[:alert]).to be_present
    end

    it "refuses to open the new-subcategory form" do
      get :new, params: { category_id: category.id }

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
      expect(flash[:alert]).to be_present
    end

    it "refuses to create a subcategory" do
      expect do
        post :create, params: { category_id: category.id,
                                deficiency_report_subcategory: { name: "Schlaglöcher" }}
      end.not_to change(DeficiencyReport::Subcategory, :count)

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
    end
  end
end
