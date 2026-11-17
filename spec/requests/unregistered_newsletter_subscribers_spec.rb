require "rails_helper"

describe "Newsletter subscription without an account", type: :request do
  it "answers an invalid e-mail address with the error script" do
    post unregistered_newsletter_subscribers_path,
         params: { unregistered_newsletter_subscriber: { email: "keine-adresse" } }, xhr: true

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "text/javascript"
    expect(UnregisteredNewsletterSubscriber.count).to eq 0
  end
end
