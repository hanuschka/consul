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

  describe "authorized providers" do
    let(:provider_x) { create(:offer_provider, name: "Träger X") }
    let(:provider_y) { create(:offer_provider, name: "Träger Y") }

    before do
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    end

    def member_of(provider, email: nil)
      create(:user, **{ email: email }.compact).tap { |user| provider.add_email(user.email) }
    end

    it "lets a user registered with a listed address in once the account is confirmed" do
      provider_x.add_email("anna@traeger.example")
      user = create(:user, :unconfirmed, email: "anna@traeger.example")
      login_as(user)

      get new_offer_path
      expect(response).to redirect_to(new_user_session_path)

      user.confirm
      login_as(user)
      get new_offer_path
      expect(response).to have_http_status(:ok)
    end

    it "refuses users with any other address, also when they post directly" do
      provider_x.add_email("anna@traeger.example")
      login_as(create(:user, email: "fremd@example.org"))

      get new_offer_path
      expect(response).to redirect_to(root_path)

      expect do
        post offers_path, params: { offer: offer_attributes }
      end.not_to change(Offer, :count)
    end

    it "assigns the offer to the provider of the account" do
      login_as(member_of(provider_x))

      post offers_path, params: { offer: offer_attributes }

      expect(Offer.last.provider).to eq provider_x
    end

    it "asks accounts of several providers to choose one" do
      user = member_of(provider_x)
      provider_y.add_email(user.email)
      login_as(user)

      expect do
        post offers_path, params: { offer: offer_attributes }
      end.not_to change(Offer, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      post offers_path, params: { offer: offer_attributes(provider_id: provider_y.id) }
      expect(Offer.last.provider).to eq provider_y
    end

    it "does not let an account create offers for a provider it does not belong to" do
      login_as(member_of(provider_x))
      provider_y

      post offers_path, params: { offer: offer_attributes(provider_id: provider_y.id) }

      expect(Offer.last.provider).to eq provider_x
    end

    it "lets every account of a provider edit the provider's offers" do
      account_a = member_of(provider_x)
      account_b = member_of(provider_x)
      offer = create(:offer, provider: provider_x, author: account_a)
      login_as(account_b)

      get edit_offer_path(offer)
      expect(response).to have_http_status(:ok)

      patch offer_path(offer), params: { offer: { contact_email: "b@traeger.example" } }
      expect(offer.reload.contact_email).to eq "b@traeger.example"
    end

    it "keeps accounts of other providers away from an offer" do
      offer = create(:offer, provider: provider_x)
      login_as(member_of(provider_y))

      get edit_offer_path(offer)
      expect(response).to redirect_to(root_path)

      patch offer_path(offer), params: { offer: { contact_email: "y@traeger.example" } }
      expect(response).to redirect_to(root_path)
      expect(offer.reload.contact_email).to be_nil
    end

    it "does not let providers move an offer to another provider" do
      user = member_of(provider_x)
      provider_y.add_email(user.email)
      offer = create(:offer, provider: provider_x)
      login_as(user)

      patch offer_path(offer), params: { offer: { provider_id: provider_y.id } }

      expect(offer.reload.provider).to eq provider_x
    end

    it "offers the add button only to accounts that may create offers" do
      allow(Setting).to receive(:[]).with("process.offers").and_return(true)
      add_links = -> { Nokogiri::HTML(response.body).css("a[href='#{new_offer_path}']") }

      get offers_path
      expect(add_links.call).to be_empty

      login_as(create(:user))
      get offers_path
      expect(add_links.call).to be_empty

      login_as(member_of(provider_x))
      get offers_path
      expect(add_links.call).to be_present
    end

    it "shows the provider select only to accounts of several providers" do
      user = member_of(provider_x)
      login_as(user)
      provider_select = -> { Nokogiri::HTML(response.body).css("select[name='offer[provider_id]']") }

      get new_offer_path
      expect(provider_select.call).to be_empty

      provider_y.add_email(user.email)
      get new_offer_path
      expect(provider_select.call.css("option").map(&:text)).to include("Träger X", "Träger Y")
    end

    it "lets administrators create offers with or without a provider" do
      login_as(admin)

      post offers_path, params: { offer: offer_attributes }
      expect(Offer.last.provider).to be_nil

      post offers_path, params: { offer: offer_attributes(provider_id: provider_y.id) }
      expect(Offer.last.provider).to eq provider_y
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

      it "filters the list by keyword and category" do
        north = create(:offer_category, :social_area, name: "Nord")
        south = create(:offer_category, :social_area, name: "Süd")
        create(:offer, title: "Schwimmen im Norden", categories: [offer_type, north])
        create(:offer, title: "Schwimmen im Süden", categories: [offer_type, south])
        create(:offer, title: "Lesecafé", categories: [offer_type, north])

        get offers_path, params: { search: "schwimmen", social_area: [north.id] }

        expect(response.body).to include("Schwimmen im Norden")
        expect(response.body).not_to include("Schwimmen im Süden", "Lesecafé")
      end

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

  describe "city check and hiding" do
    let(:provider) { create(:offer_provider, name: "Träger X") }
    let(:member) { create(:user).tap { |user| provider.add_email(user.email) } }

    before do
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
      allow(Setting).to receive(:[]).with("process.offers").and_return(true)
    end

    it "publishes a provider's new offer right away and marks it for the city" do
      login_as(member)
      post offers_path, params: { offer: offer_attributes }
      expect(Offer.last).to be_review_added

      logout
      get offers_path
      expect(response.body).to include("Schwimmen für Kinder")
    end

    it "marks a provider's change to a checked offer as changed" do
      offer = create(:offer, provider: provider)
      offer.mark_checked!
      login_as(member)

      patch offer_path(offer), params: { offer: { contact_email: "neu@traeger.example" } }

      expect(offer.reload).to be_review_changed
    end

    it "leaves the check status alone when the city edits an offer" do
      offer = create(:offer, provider: provider)
      offer.mark_checked!
      login_as(admin)

      patch offer_path(offer), params: { offer: { contact_email: "stadt@example.org" } }

      expect(offer.reload).to be_review_checked
    end

    it "takes a hidden offer off the list and its detail page" do
      offer = create(:offer, title: "Lesecafé", provider: provider)
      offer.suspend!
      login_as(create(:user))

      get offers_path
      expect(response.body).not_to include("Lesecafé")

      expect { get offer_path(offer) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps showing a hidden offer to its own provider only" do
      own = create(:offer, title: "Lesecafé", provider: provider)
      foreign = create(:offer, title: "Chor", provider: create(:offer_provider))
      [own, foreign].each(&:suspend!)
      login_as(member)

      get offers_path
      expect(response.body).to include("Lesecafé")
      expect(response.body).not_to include("Chor")

      get offer_path(own)
      expect(response).to have_http_status(:ok)
    end

    it "tells a provider that its offer is hidden" do
      suspended = create(:offer, title: "Lesecafé", provider: provider)
      suspended.suspend!
      login_as(member)

      get offers_path
      expect(response.body).to include(I18n.t("custom.offers.index.suspended_label"))

      get offer_path(suspended)
      expect(response.body).to include(I18n.t("custom.offers.show.suspended_notice"))

      suspended.unsuspend!

      get offers_path
      expect(response.body).to include("Lesecafé")
      expect(Nokogiri::HTML(response.body).css(".resource-item--header")).to be_empty
    end

    it "filters the list of a provider account, including its own suspended offers" do
      swimming = create(:offer, title: "Schwimmen", provider: provider)
      swimming.suspend!
      create(:offer, title: "Lesecafé", provider: provider).suspend!
      create(:offer, title: "Schwimmen im Freibad")
      create(:offer, title: "Schwimmen privat", provider: create(:offer_provider)).suspend!
      login_as(member)

      get offers_path, params: { search: "schwimmen" }

      expect(response.body).to include("Schwimmen", "Schwimmen im Freibad")
      expect(response.body).not_to include("Lesecafé", "Schwimmen privat")
    end

    it "keeps an offer hidden when its provider edits it" do
      offer = create(:offer, provider: provider)
      offer.suspend!
      login_as(member)

      patch offer_path(offer), params: { offer: { contact_email: "neu@traeger.example" } }

      expect(offer.reload).to be_suspended
    end
  end

  describe "expiry and deactivation" do
    let(:provider) { create(:offer_provider, name: "Träger X") }
    let(:member) { create(:user).tap { |user| provider.add_email(user.email) } }

    before do
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
      allow(Setting).to receive(:[]).with("process.offers").and_return(true)
    end

    it "takes an offer off the public site after its expiry date but keeps it for its provider" do
      current = create(:offer, title: "Lesecafé", provider: provider, expires_on: Date.current)
      expired = create(:offer, title: "Chor", provider: provider, expires_on: Date.current - 1)

      get offers_path
      expect(response.body).to include("Lesecafé")
      expect(response.body).not_to include("Chor")
      expect { get offer_path(expired) }.to raise_error(ActiveRecord::RecordNotFound)

      login_as(member)
      get offers_path
      expect(response.body).to include("Lesecafé", "Chor")
      get offer_path(expired)
      expect(response).to have_http_status(:ok)
      get offer_path(current)
      expect(response).to have_http_status(:ok)
    end

    it "lets a provider set the expiry date" do
      offer = create(:offer, provider: provider)
      login_as(member)

      patch offer_path(offer), params: { offer: { expires_on: "2027-06-30" } }

      expect(offer.reload.expires_on).to eq Date.new(2027, 6, 30)
    end

    it "lets a provider take an offer offline and back online without a new check" do
      offer = create(:offer, title: "Lesecafé", provider: provider)
      login_as(member)

      patch deactivate_offer_path(offer)
      expect(offer.reload).to be_deactivated
      logout
      get offers_path
      expect(response.body).not_to include("Lesecafé")

      login_as(member)
      patch activate_offer_path(offer)
      expect(offer.reload).not_to be_deactivated
      expect(offer).to be_review_checked
      logout
      get offers_path
      expect(response.body).to include("Lesecafé")
    end

    it "keeps an offer suspended by the administration suspended when its provider reactivates it" do
      offer = create(:offer, provider: provider)
      offer.suspend!
      offer.deactivate!
      login_as(member)

      patch activate_offer_path(offer)

      expect(offer.reload).not_to be_deactivated
      expect(offer).not_to be_published
    end

    it "shows a provider the deactivated state and the activate button" do
      offer = create(:offer, title: "Lesecafé", provider: provider)
      offer.deactivate!
      login_as(member)

      get offers_path
      expect(response.body).to include(I18n.t("custom.offers.index.deactivated_label"))

      get offer_path(offer)
      expect(response.body).to include(I18n.t("custom.offers.show.deactivated_notice"))
      expect(response.body).to include(%(action="#{activate_offer_path(offer)}"))
      expect(response.body).to include(I18n.t("custom.offers.show.activate"))
      expect(response.body).not_to include(%(action="#{deactivate_offer_path(offer)}"))
    end

    it "does not let other accounts take an offer offline" do
      offer = create(:offer, provider: provider)
      login_as(create(:user))

      patch deactivate_offer_path(offer)

      expect(offer.reload).not_to be_deactivated
    end
  end
end
