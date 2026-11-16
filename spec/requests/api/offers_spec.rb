require "swagger_helper"

RSpec.describe "Offers API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let!(:api_client) { create_api_client(access_level: :public_data) }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  before { Setting["process.offers"] = true }

  category_schema = {
    type: :array,
    items: { type: :object, properties: { id: { type: :integer }, name: { type: :string }}}
  }

  offer_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      title: { type: :string },
      short_description: { type: :string, description: "HTML" },
      times: { type: :string, nullable: true },
      costs: { type: :string, nullable: true, description: "Free text in addition to the costs categories" },
      registration: { type: :string, nullable: true },
      address: { type: :string, nullable: true },
      contact_name: { type: :string, nullable: true },
      contact_phone: { type: :string, nullable: true },
      contact_email: { type: :string, nullable: true },
      contact_website: { type: :string, nullable: true },
      expires_on: { type: :string, format: :date, nullable: true,
                    description: "Last day the offer is shown publicly, null when it does not expire" },
      updated_at: { type: :string, format: "date-time" },
      provider: {
        type: :object, nullable: true,
        description: "The provider (Träger) the offer belongs to",
        properties: { id: { type: :integer }, name: { type: :string }}
      },
      categories: {
        type: :object,
        description: "Category values per kind",
        properties: Offer::Category::KINDS.index_with { category_schema }
      },
      map_location: {
        type: :object, nullable: true,
        properties: { latitude: { type: :number }, longitude: { type: :number }}
      },
      image: { type: :object, nullable: true }
    },
    required: %w[id title categories]
  }

  path "/api/offers" do
    get "List offers" do
      tags "Offers"
      produces "application/json"
      security [bearer_auth: []]
      description "Retrieve the published offers of the offers module with their fields and categories. " \
                  "Offers suspended by the administration, deactivated by their provider or past their " \
                  "expiry date are never part of the response. Returns 404 while the offers module is " \
                  "switched off.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false,
                description: "Pagination page number (**default:** 1)"
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: "Number of offers per page (**default:** 500, max: 2000)"

      response "200", "offers found" do
        before { create(:offer) }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { offers: { type: :array, items: offer_schema }},
                   required: ["offers"]
                 },
                 pagination: { type: :object }
               },
               required: ["data"]

        run_test!
      end

      unauthorized_response
      forbidden_response
    end
  end

  path "/api/offers/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true, description: "Offer id"

    get "Show an offer" do
      tags "Offers"
      produces "application/json"
      security [bearer_auth: []]
      description "Retrieve one published offer. Suspended, deactivated and expired offers return 404." \
                  "#{ApiAccessRequirements::GET_READ_ONLY}"

      response "200", "offer found" do
        let(:id) { create(:offer).id }

        schema type: :object,
               properties: {
                 data: { type: :object, properties: { offer: offer_schema }, required: ["offer"] }
               },
               required: ["data"]

        run_test!
      end

      response "404", "offer not published" do
        let(:id) { create(:offer).tap(&:deactivate!).id }

        run_test!
      end

      unauthorized_response { let(:id) { create(:offer).id } }
    end
  end

  describe "what the offer endpoints return" do
    let(:headers) { { "Authorization" => "Bearer #{api_client.access_token}" } }

    def listed_ids
      get api_offers_path, headers: headers
      JSON.parse(response.body)["data"]["offers"].map { |offer| offer["id"] }
    end

    it "lists only published offers" do
      published = create(:offer)
      create(:offer).suspend!
      create(:offer).deactivate!
      create(:offer, expires_on: Date.current - 1)

      expect(listed_ids).to eq([published.id])
    end

    it "returns not found for suspended, deactivated and expired offers" do
      offers = [create(:offer).tap(&:suspend!), create(:offer).tap(&:deactivate!),
                create(:offer, expires_on: Date.current - 1)]

      offers.each do |offer|
        get api_offer_path(offer), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    it "shows the published fields and categories but no account data" do
      author = create(:user, username: "Anna Muster", email: "anna@traeger.example")
      provider = create(:offer_provider, name: "Träger X")
      provider.add_email("team@traeger.example")
      sport = create(:offer_category, :offer_type, name: "Sportkurs")
      offer = create(:offer, title: "Schwimmen", author: author, provider: provider,
                             contact_email: "kurse@traeger.example", categories: [sport])

      get api_offer_path(offer), headers: headers
      body = response.body
      data = JSON.parse(body)["data"]["offer"]

      expect(data["title"]).to eq("Schwimmen")
      expect(data["contact_email"]).to eq("kurse@traeger.example")
      expect(data["provider"]).to eq("id" => provider.id, "name" => "Träger X")
      expect(data["categories"]["offer_type"]).to eq([{ "id" => sport.id, "name" => "Sportkurs" }])
      expect(data["map_location"]).to be_nil
      expect(data.keys).not_to include("author", "author_id", "review_status", "suspended_at")
      expect(body).not_to include("Anna Muster", "anna@traeger.example", "team@traeger.example")
    end

    it "returns the pin of the offer, not the centre of its map view" do
      offer = create(:offer)
      offer.create_map_location!(
        latitude: 48.0, longitude: 10.0, zoom: 10, skip_masterportal_geocoding: true,
        features: { type: "FeatureCollection",
                    features: [{ type: "Feature", geometry: { type: "Point", coordinates: [11.6, 50.9] },
                                 properties: {} }] }
      )

      get api_offer_path(offer), headers: headers

      expect(JSON.parse(response.body)["data"]["offer"]["map_location"])
        .to eq("latitude" => 50.9, "longitude" => 11.6)
    end

    it "is not found while the offers module is switched off" do
      Setting["process.offers"] = false

      get api_offers_path, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
