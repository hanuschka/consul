require "rails_helper"
require_relative "../../shared/api_client_helper"

describe "Personal data in the API", type: :request do
  include ApiClientHelper

  let(:public_data_client) { create_api_client(name: "Public data client", access_level: :public_data) }
  let(:admin_client) { create_api_client(name: "Admin client", access_level: :admin) }
  let(:author) do
    create(:user, username: "Gartenfreundin").tap { |user| user.update_column(:public_activity, true) }
  end

  def headers_for(client)
    { "Authorization" => "Bearer #{client.access_token}" }
  end

  def deficiency_report_json(report, client)
    get "/api/deficiency_reports/#{report.id}", headers: headers_for(client)

    JSON.parse(response.body).dig("data", "deficiency_report")
  end

  describe "deficiency reports" do
    let(:officer) { create(:deficiency_report_officer) }
    let(:report) do
      create(:deficiency_report, author: author, admin_accepted: true, responsible: officer)
    end

    it "returns read-only clients the public name only" do
      report_data = deficiency_report_json(report, public_data_client)

      expect(report_data["author"]).to eq("public_name" => "Gartenfreundin")
      expect(report_data.keys).not_to include("author_id", "on_behalf_of", "responsible", "reporter_answer")
    end

    it "keeps the workflow fields and the reporter answer from read-only clients" do
      intake_channel = create(:deficiency_report_intake_channel)
      report.update!(reporter_answer: "Nur für Sie", intake_channel: intake_channel, assigned_at: Time.current)

      report_data = deficiency_report_json(report, public_data_client)

      expect(report_data.keys).not_to include(
        "admin_accepted", "assigned_at", "intake_channel", "deficiency_report_intake_channel_id", "hot_score"
      )
      expect(report_data["translations"].values.flat_map(&:keys)).not_to include("reporter_answer")

      admin_report_data = deficiency_report_json(report, admin_client)

      expect(admin_report_data["intake_channel"]["id"]).to eq intake_channel.id
      expect(admin_report_data["translations"].values.flat_map(&:keys)).to include("reporter_answer")
    end

    it "refuses the assigned filter to read-only clients" do
      get "/api/deficiency_reports", params: { assigned: "true" }, headers: headers_for(public_data_client)

      expect(response).to have_http_status(:forbidden)
    end

    it "hides the name of an author who hid their activity" do
      author.update!(public_activity: false)

      expect(deficiency_report_json(report, public_data_client)["author"]).to eq("public_name" => nil)
    end

    it "returns admin clients the workflow data" do
      report_data = deficiency_report_json(report, admin_client)

      expect(report_data["author"]).to eq("id" => author.id, "public_name" => "Gartenfreundin")
      expect(report_data["author_id"]).to eq author.id
      expect(report_data.dig("responsible", "id")).to eq officer.id
    end

    it "never names the staff account behind a report entered on behalf of someone" do
      report.update!(on_behalf_of: "Erika Mustermann")

      expect(deficiency_report_json(report, public_data_client)["author"]).to eq("public_name" => nil)

      report_data = deficiency_report_json(report, admin_client)

      expect(report_data["author"]).to eq("id" => author.id, "public_name" => nil)
      expect(report_data["on_behalf_of"]).to eq "Erika Mustermann"
    end

    it "does not let read-only clients fetch a report an admin has not accepted" do
      Setting["deficiency_reports.admin_acceptance_required"] = true
      report.update_column(:admin_accepted, false)

      get "/api/deficiency_reports/#{report.id}", headers: headers_for(public_data_client)
      expect(response).to have_http_status(:not_found)

      get "/api/deficiency_reports/#{report.id}", headers: headers_for(admin_client)
      expect(response).to have_http_status(:ok)
    end

    it "only accepts officers and officer groups as responsible" do
      other_user = create(:user)

      patch "/api/deficiency_reports/#{report.id}",
            params: { deficiency_report: { responsible_type: "User", responsible_id: other_user.id } },
            headers: headers_for(admin_client),
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(report.reload.responsible).to eq officer

      officer_group = create(:deficiency_report_officer_group)

      patch "/api/deficiency_reports/#{report.id}",
            params: {
              deficiency_report: {
                responsible_type: "DeficiencyReport::OfficerGroup",
                responsible_id: officer_group.id
              }
            },
            headers: headers_for(admin_client),
            as: :json
      expect(response).to have_http_status(:ok)
      expect(report.reload.responsible).to eq officer_group
    end
  end

  describe "comments" do
    let(:comment_phase) { create(:projekt_phase, active: true, frontend_visibility: true) }
    let(:public_comment) { create(:comment, commentable: comment_phase, user: author) }
    let!(:internal_reply) do
      create(:comment, commentable: public_comment.commentable, parent: public_comment).tap do |comment|
        comment.update_column(:valuation, true)
      end
    end

    def comment_json(comment, client)
      get "/api/comments/#{comment.id}", headers: headers_for(client)

      JSON.parse(response.body).dig("data", "comment")
    end

    it "hides internal valuation comments from read-only clients" do
      comment_data = comment_json(public_comment, public_data_client)

      expect(comment_data["child_comments"]).to be_nil
      expect(comment_data.keys).not_to include("user_id", "internal")
      expect(comment_data["author"]).to eq("public_name" => "Gartenfreundin")

      get "/api/comments/#{internal_reply.id}", headers: headers_for(public_data_client)
      expect(response).to have_http_status(:not_found)
    end

    it "only returns read-only clients comments on visible, active phases" do
      hidden_phase_comment = create(:comment, commentable: create(:projekt_phase, active: true, frontend_visibility: false))
      investment_comment = create(:comment, commentable: create(:budget_investment))

      get "/api/comments", headers: headers_for(public_data_client)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "comments").map { |comment| comment["id"] })
        .to eq [public_comment.id]

      [hidden_phase_comment, investment_comment].each do |comment|
        get "/api/comments/#{comment.id}", headers: headers_for(public_data_client)
        expect(response).to have_http_status(:not_found)

        get "/api/comments/#{comment.id}", headers: headers_for(admin_client)
        expect(response).to have_http_status(:ok)
      end
    end

    it "returns internal valuation comments to admin clients, marked as internal" do
      comment_data = comment_json(public_comment, admin_client)

      expect(comment_data["internal"]).to be false
      expect(comment_data["child_comments"].map { |child| [child["id"], child["internal"]] })
        .to eq [[internal_reply.id, true]]
    end
  end

  describe "proposals" do
    let(:proposal_phase) do
      create(:projekt_phase, type: "ProjektPhase::ProposalPhase", active: true, frontend_visibility: true)
    end
    let(:proposal) { create(:proposal, projekt_phase: proposal_phase, author: author, published_at: Time.current) }

    it "keeps staff acceptance from read-only clients and hides unaccepted proposals" do
      get "/api/proposals/#{proposal.id}", headers: headers_for(public_data_client)
      proposal_data = JSON.parse(response.body).dig("data", "proposal")

      expect(proposal_data.keys).not_to include("admin_accepted", "author_id", "responsible_name")

      proposal.update!(admin_accepted: false)

      get "/api/proposals/#{proposal.id}", headers: headers_for(public_data_client)
      expect(response).to have_http_status(:forbidden)

      get "/api/proposals", headers: headers_for(public_data_client)
      expect(JSON.parse(response.body).dig("data", "proposals").map { |data| data["id"] }).not_to include(proposal.id)

      get "/api/proposals/#{proposal.id}", headers: headers_for(admin_client)
      expect(JSON.parse(response.body).dig("data", "proposal", "admin_accepted")).to be false
    end
  end

  describe "ideas" do
    let(:idea) do
      create(:idea, author: author, admin_accepted_at: Time.current, official_answer: "Nur intern")
    end

    it "returns the official answer to admin clients only" do
      get "/api/ideas/#{idea.id}", headers: headers_for(public_data_client)
      idea_data = JSON.parse(response.body).dig("data", "idea")

      expect(idea_data.keys).not_to include("official_answer", "author_id")
      expect(idea_data["translations"].values.flat_map(&:keys)).not_to include("official_answer")

      get "/api/ideas/#{idea.id}", headers: headers_for(admin_client)

      expect(JSON.parse(response.body).dig("data", "idea", "official_answer")).to eq "Nur intern"
    end
  end

  describe "events" do
    let(:event_phase) { create(:projekt_phase, type: "ProjektPhase::EventPhase", active: true, frontend_visibility: true) }
    let(:event) do
      create(
        :projekt_event,
        projekt_phase: event_phase,
        registration_enabled: true,
        max_attendees: 10,
        admin_emails: "staff@example.com",
        confirmation_email_text: "Bis bald"
      )
    end

    def event_json(client)
      get "/api/events/#{event.id}", headers: headers_for(client)

      JSON.parse(response.body).dig("data", "projekt_event")
    end

    it "never returns registrations or staff addresses, and mail texts to admin clients only" do
      event_data = event_json(public_data_client)

      expect(event_data.keys).not_to include("admin_emails", "confirmation_email_text", "waitlist_email_text")
      expect(event_data["registrations"].keys).to match_array(%w[confirmed_count spots_available])

      admin_event_data = event_json(admin_client)

      expect(admin_event_data.keys).not_to include("admin_emails")
      expect(admin_event_data["confirmation_email_text"]).to eq "Bis bald"
      expect(admin_event_data["registrations"].keys).to include("waitlisted_count", "pending_confirmation_count")
    end
  end

  describe "budget investments" do
    let(:investment) do
      create(:budget_investment, author: author, winner: true, price_first_year: 500, external_url: "https://intern.example")
    end

    def investment_json(client)
      get "/api/investments/#{investment.id}", headers: headers_for(client)

      JSON.parse(response.body).dig("data", "budget_investment")
    end

    it "never returns the responsible name and keeps workflow data to admin clients" do
      investment.update_column(:responsible_name, "X1234567")
      investment_data = investment_json(public_data_client)

      expect(investment_data.keys).not_to include(
        "responsible_name", "author_id", "code", "confidence_score", "visible_to_valuators",
        "price_first_year", "external_url", "winner", "final_winner"
      )

      admin_investment_data = investment_json(admin_client)

      expect(admin_investment_data.keys).not_to include("responsible_name")
      expect(admin_investment_data["winner"]).to be true
      expect(admin_investment_data["price_first_year"]).to eq 500
    end
  end
end
