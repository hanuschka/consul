require "rails_helper"

describe "Link from a project page to its Vorhaben", type: :request do
  let(:officer) { create(:municipal_plan_officer) }
  let(:projekt) { create(:projekt, municipal_plan: plan) }
  let(:sidebar_title) { I18n.t("custom.municipal_plans.projekt_sidebar.title") }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(Setting).to receive(:[]).and_call_original
    allow(Setting).to receive(:[]).with("process.municipal_plans").and_return(true)
  end

  context "with a published Vorhaben" do
    let(:plan) { create(:municipal_plan, :published, responsible: officer, title: "Stadtteilzentrum Lobeda") }

    it "links back to the Vorhaben" do
      get page_path(projekt.page.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sidebar_title)
      expect(response.body).to include(municipal_plan_path(plan))
    end
  end

  context "with a Vorhaben still in Entwurf" do
    let(:plan) { create(:municipal_plan, responsible: officer) }

    it "shows no link" do
      get page_path(projekt.page.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(sidebar_title)
      expect(response.body).not_to include(municipal_plan_path(plan))
    end
  end

  context "without a linked Vorhaben" do
    let(:plan) { nil }

    it "renders the page without the block" do
      get page_path(projekt.page.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(sidebar_title)
    end
  end
end
