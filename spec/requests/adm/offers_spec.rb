require "rails_helper"

describe "Angebote list in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def listed_titles
    Nokogiri::HTML(response.body).css("tbody [data-field='title']")
            .map { |cell| cell.text.strip }.reject(&:empty?)
  end

  context "as an administrator" do
    before { login_as(admin) }

    it "lists every offer with its offer type and Sozialraum" do
      offer_type = create(:offer_category, :offer_type, name: "Sportkurs")
      area = create(:offer_category, :social_area, name: "Nord")
      create(:offer, title: "Schwimmen für Kinder", categories: [offer_type, area])

      get adm_offers_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Schwimmen für Kinder", "Sportkurs", "Nord")
    end

    it "finds offers by title" do
      create(:offer, title: "Schwimmen für Kinder")
      create(:offer, title: "Lesecafé")

      get adm_offers_root_path, params: { title__search: "schwimm" }

      expect(listed_titles).to eq ["Schwimmen für Kinder"]
    end

    it "shows the newest change first and sorts by title on request" do
      create(:offer, title: "Bewegung").update_column(:updated_at, 2.days.ago)
      create(:offer, title: "Atelier").update_column(:updated_at, 1.day.ago)
      create(:offer, title: "Chor").update_column(:updated_at, 3.days.ago)

      get adm_offers_root_path
      expect(listed_titles).to eq %w[Atelier Bewegung Chor]

      get adm_offers_root_path, params: { sort_by: "title", sort_direction: "desc" }
      expect(listed_titles).to eq %w[Chor Bewegung Atelier]
    end

    describe "editing" do
      let(:sport) { create(:offer_category, :offer_type, name: "Sportkurs") }
      let(:north) { create(:offer_category, :social_area, name: "Nord") }
      let(:south) { create(:offer_category, :social_area, name: "Süd") }
      let(:offer) { create(:offer, title: "Schwimmen", categories: [sport, north]) }

      it "shows the form with the current values" do
        get edit_adm_offers_offer_path(offer)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Schwimmen", "Sportkurs", "Nord")
      end

      it "saves fields, categories and the map position" do
        patch adm_offers_offer_path(offer), params: { offer: {
          title: "Schwimmen für Kinder",
          short_description: "<p>Neu</p>",
          times: "dienstags 15–17 Uhr",
          costs: "5 €",
          address: "Markt 1, Jena",
          contact_email: "info@example.org",
          category_ids: ["", sport.id, south.id],
          map_location_attributes: { latitude: 50.92, longitude: 11.58, zoom: 14 }
        } }

        expect(response).to redirect_to(adm_offers_root_path)
        offer.reload
        expect(offer.title).to eq "Schwimmen für Kinder"
        expect(offer.times).to eq "dienstags 15–17 Uhr"
        expect(offer.costs).to eq "5 €"
        expect(offer.categories).to match_array [sport, south]
        expect(offer.map_location.latitude).to eq 50.92
      end

      it "keeps the categories when the save fails" do
        patch adm_offers_offer_path(offer), params: { offer: {
          title: "", category_ids: ["", sport.id, south.id]
        } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(offer.reload.categories).to match_array [sport, north]
      end

      it "refuses to save without a Sozialraum" do
        patch adm_offers_offer_path(offer), params: { offer: { category_ids: ["", sport.id] } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(
          I18n.t("activerecord.errors.models.offer.category_required",
                 category: I18n.t("activerecord.attributes.offer/category.kinds.social_area"))
        )
        expect(offer.reload.categories).to match_array [sport, north]
      end
    end

    it "deletes an offer" do
      offer = create(:offer)

      delete adm_offers_offer_path(offer)

      expect(Offer.exists?(offer.id)).to be false
      expect(response).to redirect_to(adm_offers_root_path)
    end
  end

  context "as another user" do
    before { login_as(create(:user)) }

    it "is turned away from the list" do
      get adm_offers_root_path

      expect(response).to redirect_to(adm_root_path)
    end

    it "cannot edit an offer" do
      offer = create(:offer, title: "Schwimmen")

      patch adm_offers_offer_path(offer), params: { offer: { title: "Gekapert" } }

      expect(offer.reload.title).to eq "Schwimmen"
    end

    it "cannot delete an offer" do
      offer = create(:offer)

      delete adm_offers_offer_path(offer)

      expect(Offer.exists?(offer.id)).to be true
    end
  end
end
