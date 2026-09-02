require "rails_helper"

describe "The homepage newsletter card", type: :request do
  let(:guest) do
    User.create!(
      username: "guest_#{SecureRandom.uuid}",
      email: "guest_#{SecureRandom.uuid}@example.com",
      password: "Guest1!#{SecureRandom.alphanumeric(12)}",
      guest: true,
      confirmed_at: Time.current,
      terms_data_protection: true,
      terms_general: true
    )
  end

  # Sprockets compiles the layout's stylesheets on a concurrent-ruby worker thread, where libsass
  # blows the smaller stack and raises "Internal Error: Not enough space".
  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    set_setting("welcomepage.newsletter_subscription", true)
  end

  it "offers the subscribe form to a visitor who is not signed in" do
    get root_path

    expect(response.body).to include("newsletter-subscribtion-form")
  end

  # auto_sign_in_guest_for creates a guest on any projekt phase whose user_status is "guest", so
  # current_user is present for a visitor who never signed in — which used to flip this card to the
  # account toggle.
  it "still offers the form to a guest, rather than the account toggle" do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(guest)

    get root_path

    expect(response.body).to include("newsletter-subscribtion-form")
  end

  it "shows the account toggle to a signed-in user" do
    login_as(create(:user, newsletter: true))

    get root_path

    expect(response.body).not_to include("newsletter-subscribtion-form")
  end
end
