require "rails_helper"

describe "Angebote provider form", type: :request do
  let(:admin) { create(:administrator).user }
  let(:offer_type) { create(:offer_category, :offer_type, name: "Sportkurs") }
  let(:social_area) { create(:offer_category, :social_area, name: "Nord") }

  def offer_attributes(**overrides)
    {
      translations_attributes: { "0" => { locale: "de", title: "Schwimmen für Kinder",
                                          short_description: "<p>Im Hallenbad</p>" } },
      category_ids: ["", offer_type.id, social_area.id],
      contact_email: "angebote@example.org"
    }.merge(overrides)
  end

  before do
    allow(Setting).to receive(:[]).and_call_original
    allow(Setting).to receive(:[]).with("process.offers").and_return(false)
  end

  context "as an administrator" do
    before do
      login_as(admin)
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    end

    it "opens the empty form while the module is switched off" do
      offer_type
      social_area

      get new_offer_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sportkurs", "Nord")
    end

    it "opens the form of an existing offer" do
      offer = create(:offer, title: "Lesecafé", categories: [offer_type, social_area])

      get edit_offer_path(offer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lesecafé")
    end

    it "creates an offer while the module is switched off and returns to its edit page" do
      expect do
        post offers_path, params: { offer: offer_attributes }
      end.to change(Offer, :count).by(1)

      offer = Offer.last
      expect(response).to redirect_to(edit_offer_path(offer))
      expect(offer.author).to eq admin
      expect(offer.title).to eq "Schwimmen für Kinder"
      expect(offer.categories).to contain_exactly(offer_type, social_area)
    end

    it "does not create an offer without the required categories" do
      expect do
        post offers_path, params: { offer: offer_attributes(category_ids: [""]) }
      end.not_to change(Offer, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates an offer and its categories" do
      offer = create(:offer, categories: [offer_type, social_area])
      other_area = create(:offer_category, :social_area, name: "Süd")

      patch offer_path(offer), params: { offer: { category_ids: ["", offer_type.id, other_area.id] } }

      expect(response).to redirect_to(edit_offer_path(offer))
      expect(offer.reload.categories).to contain_exactly(offer_type, other_area)
    end

    it "keeps the categories when the update is invalid" do
      offer = create(:offer, categories: [offer_type, social_area])

      patch offer_path(offer), params: { offer: { category_ids: ["", offer_type.id] } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(offer.reload.categories).to contain_exactly(offer_type, social_area)
    end
  end

  context "as a regular user" do
    before { login_as(create(:user)) }

    it "is not allowed to open the form" do
      get new_offer_path

      expect(response).to redirect_to(root_path)
    end

    it "cannot create an offer" do
      expect do
        post offers_path, params: { offer: offer_attributes }
      end.not_to change(Offer, :count)

      expect(response).to redirect_to(root_path)
    end

    it "cannot update an offer" do
      offer = create(:offer, title: "Lesecafé")

      patch offer_path(offer), params: { offer: { contact_email: "fremd@example.org" } }

      expect(response).to redirect_to(root_path)
      expect(offer.reload.contact_email).to be_nil
    end
  end

  context "as a guest" do
    it "is sent to the sign-in page" do
      get new_offer_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
