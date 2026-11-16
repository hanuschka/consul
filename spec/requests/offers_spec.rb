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

    it "creates an offer while the module is switched off and shows it" do
      expect do
        post offers_path, params: { offer: offer_attributes }
      end.to change(Offer, :count).by(1)

      offer = Offer.last
      expect(response).to redirect_to(offer_path(offer))
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

      expect(response).to redirect_to(offer_path(offer))
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

  describe "public pages" do
    before do
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    end

    def enable_module
      allow(Setting).to receive(:[]).with("process.offers").and_return(true)
    end

    context "while the module is switched off" do
      it "hides the list" do
        expect { get offers_path }.to raise_error(FeatureFlags::FeatureDisabled)
      end

      it "hides an offer from visitors" do
        offer = create(:offer)

        expect { get offer_path(offer) }.to raise_error(FeatureFlags::FeatureDisabled)
      end

      it "hides an offer from regular users" do
        offer = create(:offer)
        login_as(create(:user))

        expect { get offer_path(offer) }.to raise_error(FeatureFlags::FeatureDisabled)
      end

      it "lets editors preview an offer" do
        offer = create(:offer, title: "Lesecafé")
        login_as(admin)

        get offer_path(offer)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Lesecafé")
      end
    end

    context "while the module is switched on" do
      before { enable_module }

      it "lists the offers sorted by title" do
        create(:offer, title: "Schwimmen für Kinder")
        create(:offer, title: "Lesecafé")

        get offers_path

        expect(response).to have_http_status(:ok)
        expect(response.body.index("Lesecafé")).to be < response.body.index("Schwimmen für Kinder")
      end

      it "shows an offer to visitors" do
        offer_type
        offer = create(:offer, title: "Lesecafé", times: "dienstags 15–17 Uhr",
                               categories: [offer_type, social_area])

        get offer_path(offer)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Lesecafé", "dienstags 15–17 Uhr", "Sportkurs", "Nord")
      end

      it "strips unsafe markup from the short description" do
        offer = create(:offer, short_description: "<p>Im Hallenbad</p><script>alert('x')</script>")

        get offer_path(offer)

        expect(response.body).to include("Im Hallenbad")
        expect(response.body).not_to include("alert('x')")
      end
    end
  end
end
