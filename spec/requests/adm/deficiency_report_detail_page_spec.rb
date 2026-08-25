require "rails_helper"

describe "The Anliegen detail page in /adm", type: :request do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:report) { create(:deficiency_report) }

  def scope(key)
    I18n.t("adm.deficiency_reports.deficiency_reports.#{key}")
  end

  def action_row
    response.body[/<div class="adm-detail-action-row.*?(?=<section)/m]
  end

  def share_panel
    response.body[/<div class="adm-share-menu__panel.*?(?=<section)/m]
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  describe "action row" do
    it "renders the five controls above the report section, in order" do
      login_as(manager)

      get adm_deficiency_reports_deficiency_report_path(report)

      row = action_row
      expect(row).to be_present

      labels = row.scan(/<span class="kern-label">([^<]+)<\/span>/).flatten
      expect(labels.first(5)).to eq([
        scope("action_row.website"),
        scope("watch.label"),
        scope("share.trigger"),
        scope("action_row.edit"),
        scope("action_row.pdf")
      ])

      controls = row.scan(/<(?:a|button)[^>]*\bkern-btn kern-btn--secondary\b/)
      expect(controls.size).to eq(5)

      expect(response.body.index("adm-detail-action-row"))
        .to be < response.body.index(">#{scope("show.section_content")}</h2>")
    end

    it "gives the watch control the bell icon and keeps it toggling" do
      login_as(manager)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to match(
        /adm-detail-action-row.*?notifications<\/span>\s*<span class="kern-label">#{scope("watch.label")}/m
      )

      expect do
        patch toggle_watch_adm_deficiency_reports_deficiency_report_path(report),
              params: { labeled: "1" },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end.to change { report.watches.count }.by(1)

      expect(response.body).to include(scope("watch.label"))
    end

    it "drops Bearbeiten for an officer who may read but not edit the report" do
      officer = create(:deficiency_report_officer)
      set_setting("deficiency_reports.admins_must_assign_officer", true)
      set_setting("deficiency_reports.officers_see_all_reports", true)
      report.update!(responsible: create(:deficiency_report_officer))

      login_as(officer.user)
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(action_row).not_to include(">#{scope("action_row.edit")}<")
      expect(action_row).to include(">#{scope("share.trigger")}<")
    end

    it "drops Teilen when the policy refuses sharing" do
      allow_any_instance_of(Adm::DeficiencyReports::DeficiencyReportPolicy)
        .to receive(:share?).and_return(false)

      login_as(manager)
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(action_row).not_to include(">#{scope("share.trigger")}<")
      expect(action_row).to include(">#{scope("action_row.edit")}<")
    end
  end

  describe "share menu" do
    before { login_as(manager) }

    it "lists officer groups and individual case workers as separate groups" do
      group = create(:deficiency_report_officer_group)
      officer = create(:deficiency_report_officer)

      get adm_deficiency_reports_deficiency_report_path(report)

      panel = share_panel
      expect(panel).to be_present
      expect(panel).to include(scope("share.officer_groups"), group.name)
      expect(panel).to include(scope("share.officers"), officer.name)
      expect(panel).to include(%(value="OfficerGroup:#{group.id}"))
      expect(panel).to include(%(value="Officer:#{officer.id}"))
    end

    it "shows the empty state instead of an empty list when no case workers exist" do
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to include(scope("share.no_officers"))
      expect(response.body).not_to include("recipients[]")
    end

    it "names the people already watching the report" do
      watcher = create(:deficiency_report_officer)
      create(:deficiency_report_watch, deficiency_report: report, user: watcher.user)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(share_panel).to include(scope("share.current_watchers"), watcher.user.name)
    end

    it "no longer renders the multi-select recipient list" do
      create(:deficiency_report_officer)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).not_to match(/<select[^>]+name="recipients\[\]"/)
    end
  end

  describe "section order" do
    before { login_as(manager) }

    it "puts the internal notes first, then report, administration and official answer" do
      get adm_deficiency_reports_deficiency_report_path(report)

      positions = [
        I18n.t("adm.memos.title"),
        scope("show.section_content"),
        scope("show.section_admin"),
        scope("show.official_answer")
      ].map { |heading| response.body.index(">#{heading}</h2>") }

      expect(positions).to all(be_present)
      expect(positions).to eq(positions.sort)
    end
  end

  describe "release toggle" do
    before { set_setting("deficiency_reports.admin_acceptance_required", true) }

    it "is gone from the detail page even for a manager who may release" do
      login_as(manager)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).not_to include(scope("show.admin_accepted_status"))
      expect(response.body).not_to include(
        accept_adm_deficiency_reports_deficiency_report_path(report)
      )
    end

    it "is gone from the detail page for an officer as well" do
      officer = create(:deficiency_report_officer)
      report.update!(responsible: officer)
      login_as(officer.user)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).not_to include(
        accept_adm_deficiency_reports_deficiency_report_path(report)
      )
    end

    it "is gone from the detail page when release is not required either" do
      set_setting("deficiency_reports.admin_acceptance_required", nil)
      login_as(manager)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).not_to include(
        accept_adm_deficiency_reports_deficiency_report_path(report)
      )
    end

    it "stays in the reports table while release is required" do
      report
      login_as(manager)

      get adm_deficiency_reports_deficiency_reports_list_path

      expect(response.body).to include(
        accept_adm_deficiency_reports_deficiency_report_path(report)
      )
    end

    it "is disabled in the table for an officer who may not release" do
      officer = create(:deficiency_report_officer)
      set_setting("deficiency_reports.admins_must_assign_officer", true)
      report.update!(responsible: officer)
      login_as(officer.user)

      get adm_deficiency_reports_deficiency_reports_list_path

      toggle = response.body[/<td[^>]*data-field="admin_accepted".*?<\/td>/m]
      expect(toggle).to be_present
      expect(toggle).to include("disabled")
    end
  end
end
