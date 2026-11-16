require "rails_helper"

describe "Angebote providers in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  context "as an administrator" do
    before { login_as(admin) }

    it "lists the providers" do
      provider = create(:offer_provider, name: "Jugendzentrum Nord")
      provider.add_email("anna@traeger.example")

      get adm_offers_providers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jugendzentrum Nord")
    end

    it "opens the forms" do
      provider = create(:offer_provider)

      get new_adm_offers_provider_path
      expect(response).to have_http_status(:ok)

      get edit_adm_offers_provider_path(provider)
      expect(response).to have_http_status(:ok)
    end

    it "creates a provider with addresses of registered and unregistered people" do
      user = create(:user, email: "anna@traeger.example")

      post adm_offers_providers_path, params: { offer_provider: {
        name: "Jugendzentrum Nord",
        email_list: "Anna@traeger.example\nben@traeger.example"
      } }

      provider = Offer::Provider.last
      expect(response).to redirect_to(adm_offers_providers_path)
      expect(provider.users).to eq [user]
      expect(provider.auto_join_emails).to eq ["ben@traeger.example"]
    end

    it "removes addresses that are no longer listed" do
      provider = create(:offer_provider)
      user = create(:user, email: "anna@traeger.example")
      provider.add_email(user.email)
      provider.add_email("ben@traeger.example")

      patch adm_offers_provider_path(provider), params: { offer_provider: { email_list: "carla@traeger.example" } }

      expect(provider.reload.users).to be_empty
      expect(provider.auto_join_emails).to eq ["carla@traeger.example"]
    end

    it "rejects invalid addresses without changing anything" do
      provider = create(:offer_provider)
      provider.add_email("anna@traeger.example")

      patch adm_offers_provider_path(provider), params: { offer_provider: { email_list: "kein-mail\nben@traeger.example" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(provider.reload.emails).to eq ["anna@traeger.example"]
    end

    it "does not delete a provider that still has offers" do
      provider = create(:offer_provider)
      create(:offer, provider: provider)

      delete adm_offers_provider_path(provider)

      expect(response).to redirect_to(adm_offers_providers_path)
      expect(Offer::Provider.exists?(provider.id)).to be true
    end

    it "deletes a provider without offers" do
      provider = create(:offer_provider)

      delete adm_offers_provider_path(provider)

      expect(Offer::Provider.exists?(provider.id)).to be false
    end
  end

  context "as a regular user" do
    it "is refused" do
      login_as(create(:user))

      get adm_offers_providers_path

      expect(response).to have_http_status(:redirect)
      expect(response).not_to redirect_to(adm_offers_providers_path)
    end
  end
end
