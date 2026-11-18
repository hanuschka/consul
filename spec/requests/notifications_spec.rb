require "rails_helper"

describe "Opening a notification", type: :request do
  let(:user) { create(:user) }

  def notification_linking_to(link)
    admin_notification = AdminNotification.create!(
      title: "New participation phase",
      body: "Have a look",
      link: link,
      segment_recipient: "all_users"
    )

    Notification.create!(user: user, notifiable: admin_notification)
  end

  before { login_as(user) }

  it "redirects to the external page an administrator linked" do
    notification = notification_linking_to("https://example.org/participation")

    get notification_path(notification)

    expect(response).to redirect_to("https://example.org/participation")
    expect(notification.reload).to be_read
  end

  it "redirects to an internal page an administrator linked" do
    notification = notification_linking_to("/projekts")

    get notification_path(notification)

    expect(response).to redirect_to("/projekts")
  end
end
