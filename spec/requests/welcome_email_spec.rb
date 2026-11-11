require "rails_helper"

describe "Welcome email", type: :request do
  let(:user) { create(:user, :unconfirmed) }

  def confirm(token)
    get user_confirmation_path(confirmation_token: token)
  end

  it "is not sent while the setting is off" do
    set_setting("email_templates.welcome_email", nil)

    expect { confirm(user.confirmation_token) }.not_to have_enqueued_mail(Mailer, :welcome)
    expect(user.reload).to be_confirmed
  end

  it "is sent once when a registration is confirmed" do
    set_setting("email_templates.welcome_email", true)

    expect { confirm(user.confirmation_token) }.to have_enqueued_mail(Mailer, :welcome).once
  end

  it "is not sent again when a changed e-mail address is confirmed" do
    set_setting("email_templates.welcome_email", true)
    confirmed_user = create(:user)
    confirmed_user.update!(email: "neu@example.org")

    expect { confirm(confirmed_user.reload.confirmation_token) }.not_to have_enqueued_mail(Mailer, :welcome)
    expect(confirmed_user.reload.email).to eq "neu@example.org"
  end
end
