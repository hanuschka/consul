require "rails_helper"

describe Projekt do
  # `Projekt::USE_SETTING_COLUMNS` is true, so `activated?` and the `activated`
  # scope both read the `projekts.activated` column — the legacy
  # `projekt_feature.main.activate` settings row is a write-only shadow kept in
  # sync by `create_default_settings`. Deactivating therefore means
  # `update!(activated: false)`; updating the settings row has no effect.
  #
  # The examples below re-fetch with `Projekt.find(projekt.id)` before asserting
  # because `meets_publish_criteria?` reads the `individual_group_values` and
  # `page` associations, which stay cached on the instance `create` returned
  # after an `<<` push or a page update.

  describe "#published?" do
    it "is true when the page status is published" do
      projekt = create(:projekt)

      expect(projekt.published?).to be true
    end

    # A projekt page is never a draft: SiteCustomization::Page forces it back to
    # published, so its visibility is decided by the projekt's own switches.
    it "stays true when the page is set to draft" do
      projekt = create(:projekt)
      projekt.page.update!(status: "draft")

      expect(Projekt.find(projekt.id).published?).to be true
    end
  end

  describe "#activated?" do
    it "is true by default (the :projekt factory activates on create)" do
      projekt = create(:projekt)

      expect(Projekt.find(projekt.id).activated?).to be true
    end

    it "is false for a deactivated projekt" do
      projekt = create(:projekt, :deactivated)

      expect(Projekt.find(projekt.id).activated?).to be false
    end
  end

  describe "#current?" do
    it "is true within the total duration window (default factory dates)" do
      projekt = create(:projekt)

      expect(Projekt.find(projekt.id).current?).to be true
    end

    it "is false once total_duration_end is in the past" do
      projekt = create(:projekt, total_duration_end: 1.day.ago)

      expect(Projekt.find(projekt.id).current?).to be false
    end

    it "is false when not activated, even within the duration window" do
      projekt = create(:projekt, :deactivated)

      expect(Projekt.find(projekt.id).current?).to be false
    end
  end

  describe "#expired?" do
    it "is false within the total duration window" do
      projekt = create(:projekt)

      expect(Projekt.find(projekt.id).expired?).to be false
    end

    it "is true once total_duration_end is in the past" do
      projekt = create(:projekt, total_duration_end: 1.day.ago)

      expect(Projekt.find(projekt.id).expired?).to be true
    end
  end

  describe "#meets_publish_criteria?" do
    # Tested directly rather than via the `published_at` side effect: the
    # `before_save :sync_published_at` callback runs while the record is still
    # new, before `after_create :create_corresponding_page` has made the page
    # the criteria depend on. So a freshly created projekt's `published_at`
    # stays nil until something saves it again — a callback-ordering nuance
    # worth knowing about, not something these examples assert on.

    it "is true when active, published, and unrestricted" do
      projekt = create(:projekt)

      expect(Projekt.find(projekt.id).meets_publish_criteria?).to be true
    end

    it "is false for a projekt with a HARD individual-group restriction" do
      hard_group = create(:individual_group, kind: "hard")
      value = create(:individual_group_value, individual_group: hard_group)
      projekt = create(:projekt)
      projekt.individual_group_values << value

      expect(Projekt.find(projekt.id).meets_publish_criteria?).to be false
    end

    it "is still true for a projekt with only a SOFT individual-group restriction" do
      soft_group = create(:individual_group, kind: "soft")
      value = create(:individual_group_value, individual_group: soft_group)
      projekt = create(:projekt)
      projekt.individual_group_values << value

      expect(Projekt.find(projekt.id).meets_publish_criteria?).to be true
    end

    it "is false once deactivated" do
      projekt = create(:projekt, :deactivated)

      expect(Projekt.find(projekt.id).meets_publish_criteria?).to be false
    end
  end

  describe ".visible_for" do
    let(:citizen) { create(:user) }

    def deactivate(projekt)
      projekt.update!(activated: false)
      Projekt.find(projekt.id)
    end

    it "shows every projekt to an administrator, including deactivated ones" do
      admin_user = create(:user)
      create(:administrator, user: admin_user)
      projekt = deactivate(create(:projekt))

      expect(Projekt.visible_for(admin_user)).to include(projekt)
    end

    it "shows every projekt to a super projekt manager, including deactivated ones" do
      manager_user = create(:user)
      create(:projekt_manager, user: manager_user, manage_all_projekts: true)
      projekt = deactivate(create(:projekt))

      expect(Projekt.visible_for(manager_user)).to include(projekt)
    end

    it "shows a deactivated projekt to a scoped manager with 'manage' permission on it" do
      projekt = deactivate(create(:projekt))
      manager_user = create(:user)
      manager = create(:projekt_manager, user: manager_user)
      create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: ["manage"])

      expect(Projekt.visible_for(manager_user)).to include(projekt)
    end

    it "shows a deactivated projekt to a scoped manager with 'review' permission on it" do
      projekt = deactivate(create(:projekt))
      manager_user = create(:user)
      manager = create(:projekt_manager, user: manager_user)
      create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: ["review"])

      expect(Projekt.visible_for(manager_user)).to include(projekt)
    end

    it "does NOT show a deactivated projekt to a scoped manager with only 'moderate' permission on it" do
      projekt = deactivate(create(:projekt))
      manager_user = create(:user)
      manager = create(:projekt_manager, user: manager_user)
      create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager,
                                          permissions: ["moderate"])

      expect(Projekt.visible_for(manager_user)).not_to include(projekt)
    end

    it "does NOT show an activated projekt to a citizen once it carries any individual-group restriction" do
      hard_group = create(:individual_group, kind: "hard")
      value = create(:individual_group_value, individual_group: hard_group)
      projekt = create(:projekt)
      projekt.individual_group_values << value

      expect(Projekt.visible_for(citizen)).not_to include(projekt)
    end

    it "shows the projekt to a citizen who holds the matching HARD group value" do
      hard_group = create(:individual_group, kind: "hard")
      value = create(:individual_group_value, individual_group: hard_group)
      projekt = create(:projekt)
      projekt.individual_group_values << value
      create(:user_individual_group_value, user: citizen, individual_group_value: value)

      expect(Projekt.visible_for(citizen)).to include(projekt)
    end

    it "does NOT show the projekt to a citizen holding the matching SOFT group value" do
      soft_group = create(:individual_group, kind: "soft")
      value = create(:individual_group_value, individual_group: soft_group)
      projekt = create(:projekt)
      projekt.individual_group_values << value
      create(:user_individual_group_value, user: citizen, individual_group_value: value)

      expect(Projekt.visible_for(citizen)).not_to include(projekt)
    end

    it "shows only activated, unrestricted projekts to an anonymous visitor" do
      visible_projekt = create(:projekt)
      hard_group = create(:individual_group, kind: "hard")
      value = create(:individual_group_value, individual_group: hard_group)
      restricted_projekt = create(:projekt)
      restricted_projekt.individual_group_values << value

      relation = Projekt.visible_for(nil)

      expect(relation).to include(visible_projekt)
      expect(relation).not_to include(restricted_projekt)
    end

    context "when a group restricting the projekt is deleted" do
      let(:group_a) { create(:individual_group, kind: "hard") }
      let(:group_b) { create(:individual_group, kind: "hard") }
      let(:value_a) { create(:individual_group_value, individual_group: group_a) }
      let(:value_b) { create(:individual_group_value, individual_group: group_b) }
      let(:admin_user) { create(:administrator).user }

      it "keeps the projekt restricted to the remaining group" do
        projekt = create(:projekt)
        projekt.individual_group_values << [value_a, value_b]
        member_b = create(:user_individual_group_value, individual_group_value: value_b).user

        group_a.destroy!

        expect(Projekt.visible_for(nil)).not_to include(projekt)
        expect(Projekt.visible_for(citizen)).not_to include(projekt)
        expect(Projekt.visible_for(member_b)).to include(projekt)
        expect(Projekt.visible_for(admin_user)).to include(projekt)
      end

      it "lifts the restriction when the deleted group was the only one" do
        projekt = create(:projekt)
        projekt.individual_group_values << value_a

        group_a.destroy!

        expect(Projekt.visible_for(nil)).to include(projekt)
        expect(Projekt.visible_for(citizen)).to include(projekt)
      end

      it "treats a leftover link to a deleted value as a restriction for every visitor" do
        projekt = create(:projekt)
        projekt.individual_group_values << [value_a, value_b]
        IndividualGroupValue.where(id: value_a.id).delete_all

        expect(Projekt.visible_for(nil)).not_to include(projekt)
        expect(Projekt.visible_for(citizen)).not_to include(projekt)
      end
    end
  end

  describe "#assign_author_as_manager" do
    it "grants a scoped (non-super) projekt-manager author all six permissions on the new projekt" do
      author_user = create(:user)
      create(:projekt_manager, user: author_user)

      projekt = create(:projekt, author: author_user)

      assignment = ProjektManagerAssignment.find_by(
        projekt: projekt,
        projekt_manager: author_user.reload.projekt_manager
      )
      expect(assignment).to be_present
      expect(assignment.permissions).to match_array(
        %w[manage moderate create_on_behalf_of get_notifications access_graphql review]
      )
    end

    it "creates no assignment when the author is a super projekt manager" do
      author_user = create(:user)
      create(:projekt_manager, user: author_user, manage_all_projekts: true)

      projekt = create(:projekt, author: author_user)

      expect(
        ProjektManagerAssignment.exists?(projekt: projekt,
                                        projekt_manager: author_user.reload.projekt_manager)
      ).to be false
    end

    it "creates no assignment when the author is an administrator without a projekt_manager record" do
      author_user = create(:user)
      create(:administrator, user: author_user)

      projekt = create(:projekt, author: author_user)

      expect(ProjektManagerAssignment.where(projekt: projekt)).to be_empty
    end
  end
end
