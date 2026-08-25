require "rails_helper"

describe Adm::DeficiencyReports::DeficiencyReportsController do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:report) { create(:deficiency_report) }

  describe "PATCH #toggle_watch" do
    before { sign_in manager }

    it "switches the bell on" do
      expect do
        patch :toggle_watch, params: { id: report.id }, format: :turbo_stream
      end.to change { report.watches.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(report.reload.watched_by?(manager)).to be(true)
    end

    it "switches the bell off again" do
      create(:deficiency_report_watch, deficiency_report: report, user: manager)

      expect do
        patch :toggle_watch, params: { id: report.id }, format: :turbo_stream
      end.to change { report.watches.count }.by(-1)

      expect(report.reload.watched_by?(manager)).to be(false)
    end

    it "only touches the current user's own watch" do
      other_watch = create(:deficiency_report_watch, deficiency_report: report)

      patch :toggle_watch, params: { id: report.id }, format: :turbo_stream

      expect(DeficiencyReport::Watch.exists?(other_watch.id)).to be(true)
    end
  end

  describe "POST #share" do
    let(:mail) { double("mail", deliver_later: true) }

    before do
      sign_in manager
      allow(DeficiencyReportMailer).to receive(:notify_shared_report).and_return(mail)
    end

    it "makes the recipient a watcher and mails them" do
      officer = create(:deficiency_report_officer)

      expect do
        post :share, params: { id: report.id, recipients: ["Officer:#{officer.id}"] }
      end.to change { report.watches.count }.by(1)

      expect(report.reload.watchers).to include(officer.user)
      expect(DeficiencyReportMailer).to have_received(:notify_shared_report)
        .with(report, officer.user, manager)
      expect(response).to redirect_to(adm_deficiency_reports_deficiency_report_path(report))
    end

    it "shares with every officer of a group" do
      group = create(:deficiency_report_officer_group)
      members = Array.new(2) { create(:deficiency_report_officer) }
      members.each do |officer|
        create(:deficiency_report_officer_group_assignment, officer: officer, officer_group: group)
      end

      expect do
        post :share, params: { id: report.id, recipients: ["OfficerGroup:#{group.id}"] }
      end.to change { report.watches.count }.by(2)

      expect(report.reload.watchers).to match_array(members.map(&:user))
    end

    it "does not share with the person doing the sharing" do
      officer = create(:deficiency_report_officer, user: manager)

      expect do
        post :share, params: { id: report.id, recipients: ["Officer:#{officer.id}"] }
      end.not_to change { report.watches.count }

      expect(DeficiencyReportMailer).not_to have_received(:notify_shared_report)
    end

    # Re-sharing must not mail somebody who is already following the Anliegen.
    it "skips recipients who already watch the report" do
      officer = create(:deficiency_report_officer)
      create(:deficiency_report_watch, deficiency_report: report, user: officer.user)

      expect do
        post :share, params: { id: report.id, recipients: ["Officer:#{officer.id}"] }
      end.not_to change { report.watches.count }

      expect(DeficiencyReportMailer).not_to have_received(:notify_shared_report)
    end

    it "ignores unknown recipient values" do
      expect do
        post :share, params: { id: report.id, recipients: ["Nonsense:1", ""] }
      end.not_to change { report.watches.count }
    end
  end

  describe "GET #unwatch" do
    it "drops the watch and returns to the report when it stays readable" do
      sign_in manager
      create(:deficiency_report_watch, deficiency_report: report, user: manager)

      expect do
        get :unwatch, params: { id: report.id }
      end.to change { report.watches.count }.by(-1)

      expect(response).to redirect_to(adm_deficiency_reports_deficiency_report_path(report))
    end

    it "is idempotent, so following the link twice cannot switch notifications back on" do
      sign_in manager

      expect { get :unwatch, params: { id: report.id } }.not_to change { report.watches.count }
      expect(response).to redirect_to(adm_deficiency_reports_deficiency_report_path(report))
    end

    # Opting out of a shared Anliegen can remove the very access the share granted, so the redirect
    # has to land on the list instead of bouncing off the policy.
    context "when the watch was the officer's only access" do
      let(:officer) { create(:deficiency_report_officer) }

      before do
        set_setting("deficiency_reports.admins_must_assign_officer", true)
        set_setting("deficiency_reports.officers_see_all_reports", false)
        report.update!(responsible: create(:deficiency_report_officer))
        create(:deficiency_report_watch, deficiency_report: report, user: officer.user)
        sign_in officer.user
      end

      it "sends the officer back to the overview" do
        expect do
          get :unwatch, params: { id: report.id }
        end.to change { report.watches.count }.by(-1)

        expect(response).to redirect_to(adm_deficiency_reports_deficiency_reports_list_path)
      end
    end
  end

  describe "GET #show authorization" do
    let(:officer) { create(:deficiency_report_officer) }

    before do
      set_setting("deficiency_reports.admins_must_assign_officer", true)
      report.update!(responsible: create(:deficiency_report_officer))
      sign_in officer.user
    end

    it "refuses an officer who is not responsible while the visibility setting is off" do
      get :show, params: { id: report.id }

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
      expect(flash[:alert]).to be_present
    end

    it "admits any officer once the visibility setting is on" do
      set_setting("deficiency_reports.officers_see_all_reports", true)

      get :show, params: { id: report.id }

      expect(response).to have_http_status(:ok)
    end

    it "admits an officer the report was shared with" do
      create(:deficiency_report_watch, deficiency_report: report, user: officer.user)

      get :show, params: { id: report.id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH #accept authorization" do
    let(:officer) { create(:deficiency_report_officer) }

    before do
      set_setting("deficiency_reports.admin_acceptance_required", true)
      set_setting("deficiency_reports.admins_must_assign_officer", true)
      report.update!(responsible: officer)
    end

    it "refuses the officer the report is assigned to" do
      sign_in officer.user

      patch :accept, params: { id: report.id, deficiency_report: { admin_accepted: true }},
                     format: :turbo_stream

      expect(report.reload.admin_accepted).to be_falsey
    end

    it "lets a manager release the report" do
      sign_in manager

      patch :accept, params: { id: report.id, deficiency_report: { admin_accepted: true }},
                     format: :turbo_stream

      expect(report.reload.admin_accepted).to be(true)
    end
  end

  describe "GET #index scoping" do
    # No rails-controller-testing in this suite, so the scoped collection is read off the controller.
    def listed_reports
      controller.instance_variable_get(:@deficiency_reports).to_a
    end

    let(:officer) { create(:deficiency_report_officer) }
    let!(:own) { create(:deficiency_report, responsible: officer) }
    let!(:shared) { create(:deficiency_report, responsible: create(:deficiency_report_officer)) }
    let!(:foreign) { create(:deficiency_report, responsible: create(:deficiency_report_officer)) }

    before do
      set_setting("deficiency_reports.admins_must_assign_officer", true)
      create(:deficiency_report_watch, deficiency_report: shared, user: officer.user)
      sign_in officer.user
    end

    it "shows an officer their own and their shared reports" do
      get :index

      expect(listed_reports).to match_array([own, shared])
    end

    it "shows everything to a manager" do
      sign_in manager

      get :index

      expect(listed_reports).to include(own, shared, foreign)
    end

    context "with the visibility setting on" do
      before { set_setting("deficiency_reports.officers_see_all_reports", true) }

      # The filter defaults to "assigned to me" so the wider scope does not change what an officer
      # sees first.
      it "defaults the officer's overview to their own reports" do
        get :index

        expect(listed_reports).to match_array([own])
      end

      it "shows every report when the filter is set to all" do
        get :index, params: { assignment_scope: ["all"] }

        expect(listed_reports).to include(own, shared, foreign)
      end
    end
  end
end
