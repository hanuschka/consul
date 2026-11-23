require "rails_helper"

describe "Angebote categories in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  context "as an administrator" do
    before { login_as(admin) }

    it "lists only the values of the chosen kind" do
      create(:offer_category, :social_area, name: "Nord")
      create(:offer_category, :target_group, name: "Senioren")

      get adm_offers_categories_path(kind: "social_area")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nord")
      expect(response.body).not_to include("Senioren")
    end

    it "opens on the first kind when none is given" do
      create(:offer_category, :offer_type, name: "Sportkurs")

      get adm_offers_categories_path

      expect(response.body).to include("Sportkurs")
    end

    it "answers an unknown kind with not found" do
      expect { get adm_offers_categories_path(kind: "colour") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "creates a value in the kind of the tab it came from" do
      get new_adm_offers_category_path(kind: "accessibility")
      expect(response).to have_http_status(:ok)

      post adm_offers_categories_path(kind: "accessibility"), params: { offer_category: { name: "Rollstuhlgerecht" } }

      category = Offer::Category.last
      expect(category.name).to eq "Rollstuhlgerecht"
      expect(category.kind).to eq "accessibility"
      expect(response).to redirect_to(adm_offers_categories_path(kind: "accessibility"))
    end

    it "does not let an edit change the kind" do
      category = create(:offer_category, :costs, name: "kostenfrei")

      patch adm_offers_category_path(category), params: { offer_category: { name: "gratis", kind: "social_area" } }

      expect(category.reload.name).to eq "gratis"
      expect(category.kind).to eq "costs"
    end

    it "deletes an unused value" do
      category = create(:offer_category, :target_group)

      delete adm_offers_category_path(category)

      expect(Offer::Category.exists?(category.id)).to be false
    end

    it "keeps a value an offer uses" do
      category = create(:offer_category, :social_area)
      create(:offer, categories: [create(:offer_category, :offer_type), category])

      delete adm_offers_category_path(category)

      expect(Offer::Category.exists?(category.id)).to be true
      expect(flash[:alert]).to eq I18n.t("adm.offers.categories.destroy.cannot_destroy")
    end

    it "reorders the values of one kind" do
      first = create(:offer_category, :target_group)
      second = create(:offer_category, :target_group)

      patch order_categories_adm_offers_categories_path(kind: "target_group"),
            params: { tree: [{ id: second.id }, { id: first.id }] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(Offer::Category.of_kind(:target_group)).to eq [second, first]
    end

    it "refuses to reorder a value of another kind" do
      other = create(:offer_category, :social_area)

      expect do
        patch order_categories_adm_offers_categories_path(kind: "target_group"),
              params: { tree: [{ id: other.id }] }, as: :json
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it "turns any other user away" do
    login_as(create(:user))

    get adm_offers_categories_path

    expect(response).to redirect_to(adm_root_path)
  end
end
