require "swagger_helper"

RSpec.describe "Municipal Plans API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let!(:api_client) { create_api_client(access_level: :public_data) }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  before { Setting["process.municipal_plans"] = true }

  path "/api/municipal_plans" do
    get "List municipal plans" do
      tags "Municipal Plans"
      produces "application/json"
      security [bearer_auth: []]
      description "Retrieve the published Vorhaben of the Vorhabenliste with every field the public " \
                  "detail page shows. Drafts, internal notes and the change log are never part of the " \
                  "response. Without `changed_since` only published Vorhaben are listed. With " \
                  "`changed_since` the list holds every Vorhaben whose last public change (release, " \
                  "archiving, re-activation) happened at or after that point, including archived ones " \
                  "(`status: archived`), so a consumer can remove them. Returns 404 while the " \
                  "Vorhabenliste module is switched off.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false,
                description: "Pagination page number (**default:** 1)"
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: "Number of Vorhaben per page (**default and maximum:** 500)"
      parameter name: :districts, in: :query, type: :string, required: false,
                description: "Comma-separated Ortsteil ids; a Vorhaben matches if it lies in any of them"
      parameter name: :topics, in: :query, type: :string, required: false,
                description: "Comma-separated Thema ids; a Vorhaben matches if it carries any of them"
      parameter name: :changed_since, in: :query, type: :string, required: false,
                description: "ISO 8601 date or timestamp. A date alone means 00:00 of that day, " \
                             "so the day itself is included."

      response "200", "municipal plans found" do
        before { create(:municipal_plan, :published) }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { municipal_plans: { type: :array, items: { type: :object }}},
                   required: ["municipal_plans"]
                 },
                 pagination: { type: :object }
               },
               required: ["data"]

        run_test!
      end

      response "400", "changed_since is not a date" do
        let(:changed_since) { "gestern" }

        run_test!
      end

      unauthorized_response
      forbidden_response
    end
  end

  path "/api/municipal_plans/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true, description: "Vorhaben id"

    get "Show a municipal plan" do
      tags "Municipal Plans"
      produces "application/json"
      security [bearer_auth: []]
      description "Retrieve one published Vorhaben. Drafts and archived Vorhaben return 404." \
                  "#{ApiAccessRequirements::GET_READ_ONLY}"

      response "200", "municipal plan found" do
        let(:id) { create(:municipal_plan, :published).id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { municipal_plan: { type: :object }},
                   required: ["municipal_plan"]
                 }
               },
               required: ["data"]

        run_test!
      end

      response "404", "municipal plan not published" do
        let(:id) { create(:municipal_plan).id }

        run_test!
      end

      unauthorized_response { let(:id) { create(:municipal_plan, :published).id } }
    end
  end

  describe "what the Vorhaben endpoints return" do
    let(:headers) { { "Authorization" => "Bearer #{api_client.access_token}" } }
    let(:officer) { create(:municipal_plan_officer) }

    def listed_ids(params = {})
      get api_municipal_plans_path, params: params, headers: headers
      JSON.parse(response.body)["data"]["municipal_plans"].map { |plan| plan["id"] }
    end

    it "lists only published Vorhaben, never drafts, archived ones or working copies" do
      published = create(:municipal_plan, :published)
      create(:municipal_plan)
      create(:municipal_plan, status: "archived")
      MunicipalPlans::WorkingCopyService.call(published)

      expect(listed_ids).to eq([published.id])
    end

    it "returns not found for a draft, an archived Vorhaben and a working copy" do
      published = create(:municipal_plan, :published)
      copy = MunicipalPlans::WorkingCopyService.call(published)

      [create(:municipal_plan), create(:municipal_plan, status: "archived"), copy].each do |hidden|
        get api_municipal_plan_path(hidden), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    it "shows the public fields and leaves out internal data" do
      plan = create(:municipal_plan, :published, responsible: officer, title: "Eichplatz",
                                                 system_mailbox_email: "postfach@jena.example")
      plan.memos.create!(user: officer.user, text: "Interner Vermerk")
      plan.update!(contact_name: "Kai Ostermann")

      get api_municipal_plan_path(plan), headers: headers
      body = response.body
      data = JSON.parse(body)["data"]["municipal_plan"]

      expect(data["title"]).to eq("Eichplatz")
      expect(data["contact_name"]).to eq("Kai Ostermann")
      expect(data["districts"].first.keys).to eq(%w[id name])
      expect(data["topics"].first.keys).to eq(%w[id name])
      expect(data["map_location"].keys).to eq(%w[latitude longitude address])
      expect(data.keys).not_to include("responsible", "system_mailbox_email", "memos", "audits")
      expect(body).not_to include("Interner Vermerk", "postfach@jena.example", officer.name)
    end

    it "filters by Ortsteil and Thema" do
      match = create(:municipal_plan, :published)
      create(:municipal_plan, :published)

      expect(listed_ids(districts: match.district_ids.join(","))).to eq([match.id])
      expect(listed_ids(topics: match.topic_ids.join(","))).to eq([match.id])
    end

    describe "changed_since" do
      def released_at(time)
        travel_to(time) { create(:municipal_plan, :published, released_at: Time.current) }
      end

      let!(:unchanged) { released_at(Time.zone.local(2026, 9, 1, 10)) }
      let!(:released) { released_at(Time.zone.local(2026, 9, 20, 0, 0)) }
      let!(:archived) do
        plan = released_at(Time.zone.local(2026, 9, 1, 10))
        travel_to(Time.zone.local(2026, 9, 21, 9)) { plan.update!(status: "archived") }
        plan
      end

      it "returns what was released or archived on or after the given day, archived ones marked" do
        get api_municipal_plans_path, params: { changed_since: "2026-09-20" }, headers: headers
        plans = JSON.parse(response.body)["data"]["municipal_plans"]

        expect(plans.map { |plan| plan["id"] }).to contain_exactly(released.id, archived.id)
        expect(plans.find { |plan| plan["id"] == archived.id }["status"]).to eq("archived")
        expect(plans.map { |plan| plan["id"] }).not_to include(unchanged.id)
      end

      it "reports the last public change of each Vorhaben" do
        get api_municipal_plans_path, params: { changed_since: "2026-09-20" }, headers: headers
        plans = JSON.parse(response.body)["data"]["municipal_plans"]

        expect(Time.zone.parse(plans.find { |plan| plan["id"] == archived.id }["last_public_change_at"]))
          .to eq(Time.zone.local(2026, 9, 21, 9))
      end

      it "takes a timestamp as well" do
        expect(listed_ids(changed_since: "2026-09-21T08:00:00+02:00")).to eq([archived.id])
      end
    end

    it "lists linked projects that are activated, in the list and on the detail endpoint" do
      plan = create(:municipal_plan, :published)
      active = create(:projekt, name: "Beteiligung Eichplatz", municipal_plan: plan)
      create(:projekt, :deactivated, name: "Deaktivierte Beteiligung", municipal_plan: plan)

      get api_municipal_plans_path, headers: headers
      listed = JSON.parse(response.body)["data"]["municipal_plans"].first["projekts"]

      get api_municipal_plan_path(plan), headers: headers
      shown = JSON.parse(response.body)["data"]["municipal_plan"]["projekts"]

      expect(listed).to eq([{ "id" => active.id, "title" => active.title, "slug" => active.page.slug }])
      expect(shown).to eq(listed)
    end

    it "caps per_page at 500" do
      get api_municipal_plans_path, params: { per_page: 100_000 }, headers: headers

      expect(JSON.parse(response.body)["pagination"]["per_page"]).to eq(500)
    end

    it "lists the Themen in their editorial order" do
      second = create(:municipal_plan_topic, given_order: 2)
      first = create(:municipal_plan_topic, given_order: 1)

      get api_municipal_plan_topics_path, headers: headers
      ids = JSON.parse(response.body)["data"]["municipal_plan_topics"].map { |topic| topic["id"] }

      expect(ids).to eq([first.id, second.id])
    end

    describe "with the module switched off" do
      before { Setting["process.municipal_plans"] = false }

      it "returns no data from any Vorhaben endpoint" do
        plan = create(:municipal_plan, :published)

        paths = [api_municipal_plans_path, api_municipal_plan_path(plan), api_municipal_plan_topics_path]

        paths.each do |path|
          get path, headers: headers

          expect(response).to have_http_status(:not_found)
          expect(response.body).not_to include(plan.title)
        end
      end
    end
  end
end
