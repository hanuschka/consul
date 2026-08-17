require "rails_helper"

describe RecipientGroup do
  it "has a valid factory" do
    expect(build(:recipient_group)).to be_valid
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe "associations" do
    it { should have_many(:newsletters).dependent(:restrict_with_exception) }
    it { should have_many(:filters).class_name("RecipientGroupFilter").dependent(:destroy) }
  end

  describe "db columns" do
    it { should have_db_column(:name).of_type(:string) }
    it { should have_db_column(:origin_class_name).of_type(:string) }
    it { should have_db_column(:origin_class_object_id).of_type(:string) }
    it { should have_db_column(:access_method).of_type(:string) }
  end

  describe "#filters" do
    let(:group) { create(:recipient_group) }

    it "returns filters ordered by position" do
      second = create(:recipient_group_filter, recipient_group: group, position: 2)
      first = create(:recipient_group_filter, recipient_group: group, position: 1)

      expect(group.filters.to_a).to eq([first, second])
    end

    it "destroys its filters along with the group" do
      create(:recipient_group_filter, recipient_group: group)

      expect { group.destroy }.to change(RecipientGroupFilter, :count).by(-1)
    end
  end

  describe ".base_options_for_kind" do
    it "returns the origins a legacy group can be built from" do
      expect(RecipientGroup.base_options_for_kind).to eq(%i[projekts user_roles])
    end
  end

  describe "#user_emails" do
    context "when the group has filters" do
      let(:group) { create(:recipient_group) }

      before { create(:recipient_group_filter, recipient_group: group) }

      it "delegates to RecipientGroupResolver" do
        resolver = instance_double(RecipientGroupResolver, user_emails: ["resolved@x.test"])
        allow(RecipientGroupResolver).to receive(:new).with(group).and_return(resolver)

        expect(group.user_emails).to eq(["resolved@x.test"])
      end
    end

    # Groups created before the filter stack name an origin class and a method
    # on it that returns user ids, instead of holding a chain of filters.
    context "when the group has no filters" do
      it "returns no emails when origin_class_name is blank" do
        group = create(:recipient_group, access_method: "newsletter_subscriber_ids")

        expect(group.user_emails).to eq([])
      end

      it "returns no emails when access_method is blank" do
        group = create(:recipient_group, origin_class_name: "User")

        expect(group.user_emails).to eq([])
      end

      it "calls the access method on the class when no object id is set" do
        subscriber = create(:user, email: "sub@x.test")
        # The newsletter writer is reset by set_default_privacy_settings_to_false
        # on create, so consent has to be written past the callback.
        subscriber.update_column(:newsletter, true)
        create(:user, email: "nosub@x.test")

        group = create(:recipient_group, origin_class_name: "User",
                                         access_method: "newsletter_subscriber_ids")

        expect(group.user_emails).to contain_exactly("sub@x.test")
      end

      it "calls the access method on the record when an object id is set" do
        projekt = create(:projekt)
        phase = create(:projekt_phase, projekt: projekt)
        create(:projekt_phase_subscription, projekt_phase: phase, user: create(:user, email: "phase@x.test"))
        create(:user, email: "other@x.test")

        group = create(:recipient_group, origin_class_name: "Projekt",
                                         origin_class_object_id: projekt.id,
                                         access_method: "any_phase_subscribers_ids")

        expect(group.user_emails).to contain_exactly("phase@x.test")
      end

      context "with access_method all_newsletter_subscriber_ids" do
        let(:group) do
          create(:recipient_group, origin_class_name: "User",
                                   access_method: "all_newsletter_subscriber_ids")
        end

        it "adds unregistered subscribers to the registered ones" do
          member = create(:user, email: "member@x.test")
          member.update_column(:newsletter, true)
          UnregisteredNewsletterSubscriber.create!(email: "guest@x.test", confirmed: true)

          expect(group.user_emails).to contain_exactly("member@x.test", "guest@x.test")
        end

        # Divergence from the filter-based path worth knowing about: the
        # newsletter_subscribers filter only picks up confirmed unregistered
        # subscribers, while this legacy branch takes every row.
        it "adds unregistered subscribers that never confirmed" do
          UnregisteredNewsletterSubscriber.create!(email: "pending@x.test", confirmed: false)

          expect(group.user_emails).to include("pending@x.test")
        end
      end
    end
  end
end
