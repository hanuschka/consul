require "rails_helper"

describe Adm::DeficiencyReports::DeficiencyReportPolicy do
  def policy_for(user)
    Adm::DeficiencyReports::DeficiencyReportPolicy.new(user, report)
  end

  let(:report) { create(:deficiency_report) }

  context "with a user who has no role" do
    let(:user) { create(:user) }

    it "grants nothing" do
      expect(policy_for(user).index?).to be(false)
      expect(policy_for(user).show?).to be(false)
      expect(policy_for(user).edit?).to be(false)
      expect(policy_for(user).add_memo?).to be(false)
    end
  end

  context "with a deficiency report manager" do
    let(:user) { create(:user) }

    before { DeficiencyReportManager.create!(user: user) }

    it "grants the full management surface" do
      policy = policy_for(user)

      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      expect(policy.edit?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.destroy?).to be(true)
      expect(policy.accept?).to be(true)
      expect(policy.settings?).to be(true)
    end

    it "grants sharing and watching" do
      policy = policy_for(user)

      expect(policy.share?).to be(true)
      expect(policy.toggle_watch?).to be(true)
      expect(policy.unwatch?).to be(true)
    end
  end

  context "with an officer" do
    let(:officer) { create(:deficiency_report_officer) }
    let(:user) { officer.user }

    it "grants the overview" do
      expect(policy_for(user).index?).to be(true)
    end

    it "never grants the manager-only actions" do
      set_setting("deficiency_reports.officers_see_all_reports", true)
      policy = policy_for(user)

      expect(policy.destroy?).to be(false)
      expect(policy.accept?).to be(false)
      expect(policy.settings?).to be(false)
      expect(policy.stats?).to be(false)
      expect(policy.new?).to be(false)
    end

    context "while assignment is not enforced" do
      before { set_setting("deficiency_reports.admins_must_assign_officer", false) }

      it "grants reading and editing on any report" do
        policy = policy_for(user)

        expect(policy.show?).to be(true)
        expect(policy.edit?).to be(true)
        expect(policy.update?).to be(true)
      end
    end

    context "while assignment is enforced" do
      before { set_setting("deficiency_reports.admins_must_assign_officer", true) }

      context "and the officer is responsible in person" do
        before { report.update!(responsible: officer) }

        it "grants reading and editing" do
          policy = policy_for(user)

          expect(policy.show?).to be(true)
          expect(policy.edit?).to be(true)
          expect(policy.update?).to be(true)
          expect(policy.add_memo?).to be(true)
        end
      end

      context "and the officer is responsible through a group" do
        before do
          group = create(:deficiency_report_officer_group)
          create(:deficiency_report_officer_group_assignment, officer: officer, officer_group: group)
          report.update!(responsible: group)
        end

        it "grants reading and editing" do
          policy = policy_for(user)

          expect(policy.show?).to be(true)
          expect(policy.edit?).to be(true)
        end
      end

      context "and the report belongs to somebody else" do
        before { report.update!(responsible: create(:deficiency_report_officer)) }

        it "grants nothing on that report while the visibility setting is off" do
          policy = policy_for(user)

          expect(policy.show?).to be(false)
          expect(policy.add_memo?).to be(false)
          expect(policy.edit?).to be(false)
          expect(policy.share?).to be(false)
        end

        # The point of the visibility setting: reading is widened, reassigning is not.
        context "with the visibility setting on" do
          before { set_setting("deficiency_reports.officers_see_all_reports", true) }

          it "grants reading, notes, sharing and the bell" do
            policy = policy_for(user)

            expect(policy.show?).to be(true)
            expect(policy.add_memo?).to be(true)
            expect(policy.audits?).to be(true)
            expect(policy.share?).to be(true)
            expect(policy.toggle_watch?).to be(true)
            expect(policy.feedback_form?).to be(true)
          end

          it "still refuses editing" do
            policy = policy_for(user)

            expect(policy.edit?).to be(false)
            expect(policy.update?).to be(false)
          end
        end

        # Sharing has to work with the visibility setting off, and it works by creating a watch for
        # the recipient — a recipient who could not open the Anliegen would have been shared nothing.
        context "when the report was shared with the officer" do
          before { create(:deficiency_report_watch, deficiency_report: report, user: user) }

          it "grants reading and notes without the visibility setting" do
            policy = policy_for(report.reload && user)

            expect(policy.show?).to be(true)
            expect(policy.add_memo?).to be(true)
          end

          it "still refuses editing" do
            expect(policy_for(user).edit?).to be(false)
          end
        end
      end

      context "and the officer manages all reports" do
        let(:officer) { create(:deficiency_report_officer, manage_all: true) }

        before { report.update!(responsible: create(:deficiency_report_officer)) }

        it "grants reading and editing on any report" do
          policy = policy_for(user)

          expect(policy.show?).to be(true)
          expect(policy.edit?).to be(true)
          expect(policy.destroy?).to be(true)
        end
      end
    end
  end
end
