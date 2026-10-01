require "swagger_helper"

RSpec.describe "Municipal Plan Topics API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let!(:api_client) { create_api_client(access_level: :public_data) }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  before { Setting["process.municipal_plans"] = true }

  path "/api/municipal_plan_topics" do
    get "List municipal plan topics" do
      tags "Municipal Plans"
      produces "application/json"
      security [bearer_auth: []]
      description "Retrieve the Themen of the Vorhabenliste in their editorial order. Their ids are " \
                  "what the `topics` filter of `/api/municipal_plans` takes. Returns 404 while the " \
                  "Vorhabenliste module is switched off.#{ApiAccessRequirements::GET_READ_ONLY}"

      response "200", "municipal plan topics found" do
        before { create(:municipal_plan_topic) }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { municipal_plan_topics: { type: :array, items: { type: :object }}},
                   required: ["municipal_plan_topics"]
                 }
               },
               required: ["data"]

        run_test!
      end

      unauthorized_response
      forbidden_response
    end
  end
end
