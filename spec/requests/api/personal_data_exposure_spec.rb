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
end
