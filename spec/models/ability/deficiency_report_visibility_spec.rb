require "rails_helper"
require "cancan/matchers"

# Who may open an Anliegen on the public side, and how
# `deficiency_reports.admin_acceptance_required` narrows that down per viewer.
#
# The backend restrictions — `admins_must_assign_officer` and `officers_see_all_reports` — are
# covered by spec/policies/adm/deficiency_reports/deficiency_report_policy_spec.rb instead; this
# file only asks what the CanCan ability answers for a visitor of the public site.
describe Ability, "deficiency report visibility" do
  # Created up front rather than lazily, because readable_ids runs its query the moment it is
  # called — a report built by the expectation's own argument would not be in the database yet.
  let!(:report)  { create(:deficiency_report) }
  let(:author)   { report.author }
  let(:stranger) { create(:user) }

  # accessible_by is only ever asked for :index here: the officer ability defines :show with a
  # block, which CanCan cannot turn into a query.
  def readable_ids(user)
    DeficiencyReport.accessible_by(Ability.new(user), :index).ids
  end

  context "while admin acceptance is not required" do
    before { set_setting("deficiency_reports.admin_acceptance_required", false) }

    it "opens an unaccepted report to everybody" do
      expect(Ability.new(nil)).to be_able_to(:show, report)
      expect(Ability.new(stranger)).to be_able_to(:show, report)
      expect(Ability.new(author)).to be_able_to(:show, report)
    end

    it "lists an unaccepted report for everybody" do
      expect(readable_ids(nil)).to include(report.id)
      expect(readable_ids(stranger)).to include(report.id)
    end
  end

  context "while admin acceptance is required" do
    before { set_setting("deficiency_reports.admin_acceptance_required", true) }

    context "and the report is still pending" do
      it "hides it from an anonymous visitor" do
        expect(Ability.new(nil)).not_to be_able_to(:show, report)
        expect(readable_ids(nil)).not_to include(report.id)
      end

      # Guests fall through to Abilities::Everyone, which carries no author exception at all. They
      # cannot file an Anliegen either, so there is no guest whose own report this could hide.
      it "hides it from a guest user" do
        guest = create(:user, guest: true)

        expect(Ability.new(guest)).not_to be_able_to(:show, report)
        expect(Ability.new(guest)).not_to be_able_to(:create, DeficiencyReport)
      end

      it "hides it from another logged-in user" do
        expect(Ability.new(stranger)).not_to be_able_to(:show, report)
        expect(readable_ids(stranger)).not_to include(report.id)
      end

      it "still opens it for its own author" do
        expect(Ability.new(author)).to be_able_to(:show, report)
        expect(readable_ids(author)).to include(report.id)
      end

      # The author exception is a rule of its own, OR'd in — so it must widen the author's view of
      # their own report and nobody else's.
      it "does not open somebody else's pending report for an author" do
        other = create(:deficiency_report)

        expect(Ability.new(author)).not_to be_able_to(:show, other)
        expect(readable_ids(author)).not_to include(other.id)
      end

      it "opens it for an officer" do
        officer = create(:deficiency_report_officer)

        expect(Ability.new(officer.user)).to be_able_to(:show, report)
        expect(readable_ids(officer.user)).to include(report.id)
      end

      it "opens it for a deficiency report manager" do
        manager = create(:user)
        DeficiencyReportManager.create!(user: manager)

        expect(Ability.new(manager)).to be_able_to(:show, report)
      end

      it "opens it for an administrator" do
        expect(Ability.new(create(:administrator).user)).to be_able_to(:show, report)
      end

      it "withholds voting from everybody but the author" do
        expect(Ability.new(stranger)).not_to be_able_to(:vote, report)
        expect(Ability.new(author)).to be_able_to(:vote, report)
      end
    end

    context "and the report was accepted" do
      before { report.update!(admin_accepted: true) }

      it "opens it to everybody again" do
        expect(Ability.new(nil)).to be_able_to(:show, report)
        expect(Ability.new(stranger)).to be_able_to(:show, report)
        expect(readable_ids(nil)).to include(report.id)
        expect(readable_ids(stranger)).to include(report.id)
      end
    end

    # The page and the list deliberately disagree for the author: the ability admits them to their
    # own pending Anliegen, and DeficiencyReportsController#index then narrows the accessible scope
    # with `.admin_accepted` a second time, so a pending Anliegen never reaches the public list —
    # not even its author's copy of it.
    it "keeps the author's pending report out of the list the index builds" do
      accessible = DeficiencyReport.accessible_by(Ability.new(author), :index)

      expect(accessible.ids).to include(report.id)
      expect(accessible.admin_accepted.ids).not_to include(report.id)
    end
  end

  # A signed link from the on-behalf-of account mail, the only way a pending Anliegen opens for
  # somebody with no account: staff filed it in their name and they have no password yet.
  describe "the on-behalf-of preview pass" do
    let(:preview_gid) { report.to_gid.to_s }

    before { set_setting("deficiency_reports.admin_acceptance_required", true) }

    it "opens the one pending report it names" do
      ability = Ability.new(nil, preview_gid: preview_gid)

      expect(ability).to be_able_to(:show, report)
      expect(ability).to be_able_to(:preview, report)
    end

    it "opens nothing else" do
      other = create(:deficiency_report)

      expect(Ability.new(nil, preview_gid: preview_gid)).not_to be_able_to(:show, other)
    end

    it "grants reading only" do
      ability = Ability.new(nil, preview_gid: preview_gid)

      expect(ability).not_to be_able_to(:update, report)
      expect(ability).not_to be_able_to(:destroy, report)
      expect(ability).not_to be_able_to(:create, DeficiencyReport)
    end

    it "grants nothing when no pass was carried" do
      expect(Ability.new(nil, preview_gid: nil)).not_to be_able_to(:show, report)
      expect(Ability.new(nil, preview_gid: "")).not_to be_able_to(:show, report)
      expect(Ability.new(nil, preview_gid: "not-a-global-id")).not_to be_able_to(:show, report)
    end

    # A pass outlives a rename, so it can still name a model that has since gone.
    it "grants nothing when the pass names a class that no longer exists" do
      stale = preview_gid.sub("DeficiencyReport", "NoSuchModelAnyMore")

      expect { Ability.new(nil, preview_gid: stale) }.not_to raise_error
      expect(Ability.new(nil, preview_gid: stale)).not_to be_able_to(:show, report)
    end

    # The rule is defined last on purpose, and in CanCan the last rule wins — so it has to be a pass
    # for one record and never the reason an earlier rule stops applying.
    it "does not narrow what the visitor could already read" do
      accepted = create(:deficiency_report, admin_accepted: true)

      expect(Ability.new(nil, preview_gid: preview_gid)).to be_able_to(:show, accepted)
    end
  end
end
