require "rails_helper"

describe Newsletter do
  let(:newsletter) { build(:newsletter) }

  it "is valid" do
    expect(newsletter).to be_valid
  end

  it "is not valid without a subject" do
    newsletter.subject = nil
    expect(newsletter).not_to be_valid
  end

  it "is not valid without a segment_recipient" do
    newsletter.segment_recipient = nil
    expect(newsletter).not_to be_valid
  end

  it "is not valid with an inexistent user segment for segment_recipient" do
    newsletter.segment_recipient = "invalid_user_segment_name"
    expect(newsletter).not_to be_valid
  end

  it "is not valid without a from" do
    newsletter.from = nil
    expect(newsletter).not_to be_valid
  end

  it "is not valid without a body" do
    newsletter.body = nil
    expect(newsletter).not_to be_valid
  end

  it "validates from attribute email format" do
    newsletter.from = "this_is_not_an_email"
    expect(newsletter).not_to be_valid
  end

  describe "#valid_segment_recipient?" do
    it "is false when segment_recipient value is invalid" do
      newsletter.segment_recipient = "invalid_segment_name"
      error = "The user recipients segment is invalid"

      expect(newsletter).not_to be_valid
      expect(newsletter.errors.messages[:segment_recipient]).to include(error)
    end
  end

  describe "#list_of_recipient_emails" do
    let(:strong_password) { "Judgment1day!" }

    before do
      # The GDPR-conformity `before_create` callback in custom User flips
      # `newsletter` to false during create, so we set it explicitly afterwards.
      newsletter_user = create(:user, email: "newsletter_user@consul.dev",
                                      password: strong_password)
      newsletter_user.update_column(:newsletter, true)

      unconfirmed_user = create(:user, email: "newsletter_unconfirmed_user@consul.dev",
                                       password: strong_password, confirmed_at: nil)
      unconfirmed_user.update_column(:newsletter, true)

      create(:user, email: "no_news_user@consul.dev", password: strong_password)
      create(:user, email: "erased_user@consul.dev", password: strong_password).erase
    end

    context "with a segment_recipient and respect_newsletter_optout (default)" do
      # `newsletter` is built (not persisted) and intentionally has no
      # recipient_group so the segment branch of #list_of_recipient_emails wins.
      before { newsletter.segment_recipient = "all_users" }

      it "returns only users with newsletter: true (intersected with the opt-in list)" do
        expect(newsletter.list_of_recipient_emails).to eq ["newsletter_user@consul.dev"]
      end
    end

    context "with a segment_recipient and respect_newsletter_optout disabled" do
      before do
        newsletter.segment_recipient = "all_users"
        newsletter.respect_newsletter_optout = false
      end

      it "still returns only newsletter: true users because the segment itself filters them" do
        # UserSegments.user_segment_emails(:all_users) applies `.newsletter`
        # (newsletter: true scope) at the segment level, so disabling the
        # opt-out intersect does not surface `no_news_user` either.
        expect(newsletter.list_of_recipient_emails).to eq ["newsletter_user@consul.dev"]
      end
    end

    context "with a recipient_group using a manual_users filter" do
      let(:recipient_group) { create(:recipient_group, name: "Manual group") }

      before do
        create(:recipient_group_filter,
               recipient_group: recipient_group,
               kind: "manual_users",
               operator: "include",
               params: { user_ids: User.pluck(:id) })
        newsletter.update!(recipient_group: recipient_group, segment_recipient: nil)
      end

      it "intersects with the opt-in list when respect_newsletter_optout is true" do
        # ManualUsers resolver yields all confirmed, non-erased users
        # (newsletter_user + no_news_user); the intersect then keeps only
        # users with newsletter: true.
        expect(newsletter.list_of_recipient_emails).to eq ["newsletter_user@consul.dev"]
      end

      it "returns every email the resolver yields when respect_newsletter_optout is false" do
        newsletter.update!(respect_newsletter_optout: false)

        # ManualUsers resolver uses User.actual, which already drops erased + unconfirmed.
        expect(newsletter.list_of_recipient_emails)
          .to contain_exactly("newsletter_user@consul.dev", "no_news_user@consul.dev")
      end
    end

    context "with a recipient_group that includes unregistered newsletter subscribers" do
      let(:recipient_group) { create(:recipient_group, name: "Newsletter subscribers group") }

      before do
        UnregisteredNewsletterSubscriber.create!(email: "external_subscriber@consul.dev",
                                                 confirmed: true)
        UnregisteredNewsletterSubscriber.create!(email: "external_unconfirmed@consul.dev",
                                                 confirmed: false)
        create(:recipient_group_filter,
               recipient_group: recipient_group,
               kind: "newsletter_subscribers",
               operator: "include",
               params: { include_unregistered: true })
        newsletter.update!(recipient_group: recipient_group, segment_recipient: nil)
      end

      it "keeps confirmed unregistered subscribers when respect_newsletter_optout is true" do
        # Confirmed unregistered subscribers are opt-ins by definition and are part of
        # the opt-in union the model uses for the intersect, so they must NOT be filtered
        # out. Unconfirmed unregistered subscribers are excluded by the resolver itself.
        expect(newsletter.list_of_recipient_emails)
          .to contain_exactly("newsletter_user@consul.dev", "external_subscriber@consul.dev")
      end
    end
  end

  describe "#email_safe_body" do
    let(:newsletter) { build(:newsletter) }

    before do
      Setting["url"] = "https://consul.example.org"
      Current.settings = nil
    end

    it "returns an empty string when body is blank" do
      newsletter.body = ""
      expect(newsletter.email_safe_body).to eq("")
    end

    context "absolute URL rewriting" do
      it "rewrites relative anchor href to absolute URL using Setting[url]" do
        newsletter.body = '<a href="/processes/1">link</a>'

        expect(newsletter.email_safe_body).to include('href="https://consul.example.org/processes/1"')
      end

      it "works when Setting[url] has a trailing slash" do
        Setting["url"] = "https://consul.example.org/"
        Current.settings = nil
        newsletter.body = '<a href="/processes/1">link</a>'

        expect(newsletter.email_safe_body).to include('href="https://consul.example.org/processes/1"')
      end

      it "leaves anchor hashes untouched" do
        newsletter.body = '<a href="#top">top</a>'

        expect(newsletter.email_safe_body).to include('href="#top"')
      end

      it "leaves mailto links untouched" do
        newsletter.body = '<a href="mailto:foo@bar.de">mail</a>'

        expect(newsletter.email_safe_body).to include('href="mailto:foo@bar.de"')
      end

      it "leaves tel links untouched" do
        newsletter.body = '<a href="tel:+491234">call</a>'

        expect(newsletter.email_safe_body).to include('href="tel:+491234"')
      end

      it "leaves absolute http(s) links untouched" do
        newsletter.body = '<a href="https://other.org/x">other</a>'

        expect(newsletter.email_safe_body).to include('href="https://other.org/x"')
      end

      it "does not crash on invalid URLs and leaves them unchanged" do
        newsletter.body = '<a href="http://[invalid">broken</a>'

        expect { newsletter.email_safe_body }.not_to raise_error
      end

      it "rewrites relative img src to absolute URL" do
        newsletter.body = '<img src="/uploads/x.jpg">'
        result = newsletter.email_safe_body

        expect(result).to include('src="https://consul.example.org/uploads/x.jpg"')
      end

      it "leaves cid: image src untouched" do
        newsletter.body = '<img src="cid:image001.jpg">'

        expect(newsletter.email_safe_body).to include('src="cid:image001.jpg"')
      end

      it "leaves data: image src untouched" do
        newsletter.body = '<img src="data:image/png;base64,AAAA">'

        expect(newsletter.email_safe_body).to include('src="data:image/png;base64,AAAA"')
      end
    end

    context "image height handling" do
      it "removes the height attribute from a standalone img and adds height:auto in the style" do
        newsletter.body = '<img src="/uploads/x.jpg" height="300" width="400">'
        result = newsletter.email_safe_body
        img = Nokogiri::HTML.fragment(result).at_css("img")

        expect(img["height"]).to be_nil
        expect(img["width"]).to eq("400")
        expect(img["style"]).to match(/height\s*:\s*auto/)
      end

      it "removes the height: property from inline style and replaces it with height:auto" do
        newsletter.body = '<img src="/uploads/x.jpg" style="height: 250px; width: 400px;">'
        result = newsletter.email_safe_body
        img = Nokogiri::HTML.fragment(result).at_css("img")

        expect(img["style"]).not_to match(/height\s*:\s*250px/)
        expect(img["style"]).to match(/height\s*:\s*auto/)
        expect(img["style"]).to match(/width\s*:\s*400px/)
      end

      it "ensures max-width:100% is present on standalone images" do
        newsletter.body = '<img src="/uploads/x.jpg">'
        result = newsletter.email_safe_body
        img = Nokogiri::HTML.fragment(result).at_css("img")

        expect(img["style"]).to match(/max-width\s*:\s*100%/)
      end
    end

    context "figure-wrapped images" do
      it "scales width via percentage and never emits a height attribute" do
        newsletter.body = <<~HTML
          <figure class="image image_resized" style="width:50%;">
            <img src="/uploads/foo.jpg" width="800" height="400">
          </figure>
        HTML

        result = newsletter.email_safe_body(container_width: 600)
        img = Nokogiri::HTML.fragment(result).at_css("img")

        expect(img["width"]).to eq("300")
        expect(img["height"]).to be_nil
        expect(img["style"]).to match(/height\s*:\s*auto/)
        expect(img["style"]).to match(/max-width\s*:\s*100%/)
      end

      it "rewrites relative src inside a figure to an absolute URL" do
        newsletter.body = <<~HTML
          <figure class="image image_resized" style="width:50%;">
            <img src="/uploads/foo.jpg" width="800" height="400">
          </figure>
        HTML

        result = newsletter.email_safe_body

        expect(result).to include('src="https://consul.example.org/uploads/foo.jpg"')
      end
    end
  end

  describe "#deliver", :delay_jobs do
    let!(:proposals) { Array.new(3) { create(:proposal) } }

    let!(:recipients) { proposals.map(&:author).map(&:email) }
    let!(:newsletter) { create(:newsletter, segment_recipient: "proposal_authors") }

    before do
      create(:debate)
      reset_mailer
    end

    it "sends an email with the newsletter to every recipient" do
      newsletter.deliver

      recipients.each do |recipient|
        email = Mailer.newsletter(newsletter, recipient)
        expect(email).to deliver_to(recipient)
      end

      Delayed::Job.all.map(&:invoke_job)
      expect(ActionMailer::Base.deliveries.count).to eq(3)
    end

    it "sends emails in batches" do
      allow(newsletter).to receive(:batch_size).and_return(1)

      newsletter.deliver

      expect(Delayed::Job.count).to eq(3)
    end

    it "sends batches in time intervals" do
      allow(newsletter).to receive(:batch_size).and_return(1)
      allow(newsletter).to receive(:batch_interval).and_return(1.second)
      allow(newsletter).to receive(:first_batch_run_at).and_return(Time.current)

      newsletter.deliver

      now = newsletter.first_batch_run_at

      first_batch_run_at  = now.change(usec: 0)
      second_batch_run_at = (now + 1.second).change(usec: 0)
      third_batch_run_at  = (now + 2.seconds).change(usec: 0)

      expect(Delayed::Job.count).to eq(3)
      expect(Delayed::Job.first.run_at.change(usec: 0)).to eq(first_batch_run_at)
      expect(Delayed::Job.second.run_at.change(usec: 0)).to eq(second_batch_run_at)
      expect(Delayed::Job.third.run_at.change(usec: 0)).to eq(third_batch_run_at)
    end

    it "logs users that have received the newsletter" do
      newsletter.deliver

      expect(Activity.count).to eq(3)

      recipients.each do |email|
        user = User.find_by(email: email)
        activity = Activity.find_by(user: user)

        expect(activity.user_id).to eq(user.id)
        expect(activity.action).to eq("email")
        expect(activity.actionable).to eq(newsletter)
      end
    end

    it "skips invalid emails" do
      Proposal.destroy_all
      create(:user, :with_proposal, email: "valid@consul.dev")
      create(:user, :with_proposal, email: "invalid@consul..dev")

      newsletter.deliver

      expect(Activity.count).to eq(1)
      expect(Activity.first.user.email).to eq("valid@consul.dev")
      expect(Activity.first.action).to eq("email")
      expect(Activity.first.actionable).to eq(newsletter)
    end
  end

  describe "RecipientGroup deletion with soft-deleted newsletters" do
    let(:recipient_group) do
      RecipientGroup.create!(
        name: "Test group",
        origin_class_name: "User",
        access_method: "newsletter_subscriber_ids"
      )
    end

    it "still references the recipient_group via the FK after a newsletter is soft-deleted" do
      newsletter = create(:newsletter, recipient_group: recipient_group)
      newsletter.destroy

      expect(newsletter.reload.hidden_at).to be_present
      expect(Newsletter.where(recipient_group_id: recipient_group.id)).to be_empty
      expect(Newsletter.with_hidden.where(recipient_group_id: recipient_group.id)).to include(newsletter)
    end

    it "raises ActiveRecord::InvalidForeignKey when destroying a recipient_group whose only newsletter is soft-deleted" do
      newsletter = create(:newsletter, recipient_group: recipient_group)
      newsletter.destroy

      # `dependent: :restrict_with_exception` does not see soft-deleted records,
      # so Rails-level guard is bypassed and Postgres raises the FK violation.
      expect { recipient_group.destroy! }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(RecipientGroup.exists?(recipient_group.id)).to be true
    end

    it "raises ActiveRecord::DeleteRestrictionError when destroying a recipient_group with active newsletters" do
      create(:newsletter, recipient_group: recipient_group)

      expect { recipient_group.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
      expect(RecipientGroup.exists?(recipient_group.id)).to be true
    end
  end
end
