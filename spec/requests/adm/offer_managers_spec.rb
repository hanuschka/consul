require "rails_helper"

describe "Angebote-Administrator access", type: :request do
  let(:offer_manager) { create(:offer_manager).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def section_links
    Nokogiri::HTML(response.body).css("a[href]").map { |link| link["href"] }
  end

  context "as an Angebote-Administrator" do
    before { login_as(offer_manager) }

    it "opens the offers list, hides an offer and adds a category" do
      offer = create(:offer, title: "Schwimmen für Kinder")

      get adm_offers_root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Schwimmen für Kinder")

      patch suspend_adm_offers_offer_path(offer)
      expect(offer.reload).to be_suspended

      post adm_offers_categories_path(kind: "accessibility"), params: { offer_category: { name: "Rollstuhlgerecht" } }
      expect(Offer::Category.last.name).to eq "Rollstuhlgerecht"
    end

    it "edits an offer with image and map position" do
      offer = create(:offer, title: "Schwimmen")

      get edit_adm_offers_offer_path(offer)
      expect(response).to have_http_status(:ok)

      patch adm_offers_offer_path(offer), params: { offer: {
        title: "Schwimmen für Kinder",
        map_location_attributes: { latitude: 50.92, longitude: 11.58, zoom: 14 },
        image_attributes: {
          title: "Becken",
          user_id: offer_manager.id,
          attachment: fixture_file_upload("clippy.jpg", "image/jpeg")
        }
      } }

      offer.reload
      expect(offer.title).to eq "Schwimmen für Kinder"
      expect(offer.map_location.latitude).to eq 50.92
      expect(offer.image.attachment).to be_attached
    end

    it "reaches providers, import and settings" do
      [adm_offers_providers_path, new_adm_offers_import_path, adm_offers_settings_path].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
      end
    end

    it "sees only the offers section in the menu" do
      get adm_offers_root_path

      expect(section_links).to include(adm_offers_root_path)
      expect(section_links).not_to include(adm_users_path, adm_officing_root_path, adm_projekts_root_path)
    end

    it "is refused in other /adm areas via a direct URL" do
      [adm_users_path, adm_officing_root_path, adm_projekts_root_path].each do |path|
        get path
        expect(response).to have_http_status(:redirect), path
      end
    end

    it "cannot add other Angebote-Administratoren" do
      user = create(:user)

      post adm_role_assignment_path, params: { role: "offer_manager", user_id: user.id }

      expect(user.reload).not_to be_offer_manager
    end

    it "previews a hidden offer on the public pages" do
      Setting["process.offers"] = true
      offer = create(:offer, title: "Lesecafé")
      offer.suspend!

      get offers_path
      expect(response.body).to include("Lesecafé")

      get offer_path(offer)
      expect(response).to have_http_status(:ok)
    end
  end

  context "as a user without this access" do
    before { login_as(create(:user)) }

    it "is refused in every part of the offers module" do
      offer = create(:offer)

      [adm_offers_root_path, edit_adm_offers_offer_path(offer), adm_offers_categories_path,
       adm_offers_providers_path, new_adm_offers_import_path, adm_offers_settings_path].each do |path|
        get path
        expect(response).to redirect_to(adm_root_path), path
      end

      patch suspend_adm_offers_offer_path(offer)
      expect(offer.reload).not_to be_suspended
    end
  end

  describe "Angebote-Administratoren page" do
    it "lists, finds and removes Angebote-Administratoren for an administrator" do
      manager = offer_manager
      login_as(create(:administrator).user)
      candidate = create(:user, username: "Kandidatin")

      get adm_offers_managers_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(manager.email)

      post search_adm_offers_managers_path, params: { search: "Kandidatin" }, as: :turbo_stream
      expect(response.body).to include(candidate.email)

      delete adm_offers_manager_path(offer_manager.offer_manager), as: :turbo_stream
      expect(offer_manager.reload).not_to be_offer_manager
    end

    it "is closed to Angebote-Administratoren" do
      login_as(offer_manager)

      get adm_offers_managers_path
      expect(response).to redirect_to(adm_root_path)

      delete adm_offers_manager_path(offer_manager.offer_manager), as: :turbo_stream
      expect(offer_manager.reload).to be_offer_manager
    end
  end

  it "lets an administrator give and take the role" do
    user = create(:user)
    login_as(create(:administrator).user)

    post adm_role_assignment_path, params: { role: "offer_manager", user_id: user.id }
    expect(user.reload).to be_offer_manager

    delete adm_role_assignment_path, params: { role: "offer_manager", user_id: user.id }, as: :turbo_stream
    expect(user.reload).not_to be_offer_manager
  end
end
