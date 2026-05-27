require "rails_helper"

describe RecipientGroups::FilterResolvers::NewsletterSubscribers do
  let!(:opted_in) do
    create(:user, email: "opted@x.test", skip_password_validation: true).tap do |u|
      u.update_column(:newsletter, true)
    end
  end
  let!(:opted_out) { create(:user, email: "out@x.test", skip_password_validation: true) }
  let!(:erased) do
    create(:user, email: "erased@x.test", skip_password_validation: true).tap do |u|
      u.update_columns(newsletter: true, erased_at: Time.current)
    end
  end

  it "returns users with newsletter consent (excluding erased)" do
    emails = described_class.new({}).emails
    expect(emails).to contain_exactly("opted@x.test")
  end

  context "with include_unregistered: true" do
    let!(:unreg) { UnregisteredNewsletterSubscriber.create!(email: "ext@x.test", confirmed: true) }
    let!(:unconfirmed) { UnregisteredNewsletterSubscriber.create!(email: "pending@x.test", confirmed: false) }

    it "adds confirmed unregistered subscribers" do
      emails = described_class.new("include_unregistered" => true).emails
      expect(emails).to contain_exactly("opted@x.test", "ext@x.test")
    end
  end
end
