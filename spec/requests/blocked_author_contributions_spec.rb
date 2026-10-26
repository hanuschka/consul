require "rails_helper"
require Rails.root.join("spec/shared/api_client_helper")

describe "Contributions of a blocked user in the API" do
  include ApiClientHelper

  let(:api_client) { create_api_client }
  let(:headers) { { "Authorization" => "Bearer #{api_client.access_token}" } }
  let(:blocked_user) { create(:user) }

  def listed_titles(path, key)
    get path, headers: headers

    JSON.parse(response.body).dig("data", key).map { |item| item["title"] }
  end

  it "leaves out the ideas of a blocked user" do
    create(:idea, :accepted, author: blocked_user, title: "Idee des gesperrten Nutzers")
    create(:idea, :accepted, title: "Sichtbare Idee")

    blocked_user.block

    expect(listed_titles("/api/ideas", "ideas")).to eq(["Sichtbare Idee"])
  end

  it "leaves out the deficiency reports of a blocked user" do
    create(:deficiency_report, author: blocked_user, admin_accepted: true,
                               title: "Meldung des gesperrten Nutzers")
    create(:deficiency_report, admin_accepted: true, title: "Sichtbare Meldung")

    blocked_user.block

    expect(listed_titles("/api/deficiency_reports", "deficiency_reports")).to eq(["Sichtbare Meldung"])
  end
end
