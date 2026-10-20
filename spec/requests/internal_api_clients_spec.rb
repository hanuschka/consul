require "rails_helper"

describe "Connecting to the DT service", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    http_response = double(
      code: 404,
      message: "Not Found",
      body: '{"error":"Client not precreated on app"}'
    )
    allow(http_response).to receive(:[]) { |key| { "error" => "Client not precreated on app" }[key] }

    allow(DtApi::Client).to receive(:new)
      .and_return(double(clients: double(connect: DtApi::Response.new(http_response))))

    login_as(admin)
  end

  it "redirects with the DT error when the service rejects the connection" do
    post connect_api_clients_path

    expect(response).to have_http_status(:redirect)
    expect(flash[:error]).to eq "Error connecting to DT. HTTP code: 404, error: Client not precreated on app"
  end
end
