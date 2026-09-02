require "rails_helper"

describe "Intake channel on the reports statistics page", type: :request do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:category) { create(:deficiency_report_category) }

  def stats_label(key)
    I18n.t("adm.deficiency_reports.stats.show.#{key}")
  end

  def row_named(key)
    %(adm-metric-row__name" title="#{stats_label(key)}")
  end

  # Sprockets compiles the layout's stylesheets on a concurrent-ruby worker thread, where libsass
  # blows the smaller stack and raises "Internal Error: Not enough space".
  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    create(:deficiency_report_status)
    login_as(manager)
  end

  describe "the bar chart" do
    it "is rendered alongside the status and category charts" do
      channel = create(:deficiency_report_intake_channel, name: "Telefon")
      create(:deficiency_report, category: category, intake_channel: channel)

      get adm_deficiency_reports_stats_path

      expect(response.body).to match(/#{stats_label("charts.by_intake_channel")}.*?data-chart-labels/m)
    end

    it "is omitted when no report has an intake channel" do
      create(:deficiency_report, category: category, intake_channel: nil)

      get adm_deficiency_reports_stats_path

      expect(response.body).not_to include(stats_label("charts.by_intake_channel"))
    end
  end

  describe "the detail table" do
    it "is rendered as a fourth table grouped by intake channel" do
      channel = create(:deficiency_report_intake_channel, name: "Telefon")
      create(:deficiency_report, category: category, intake_channel: channel)

      get adm_deficiency_reports_stats_path

      expect(response.body).to include(">#{stats_label("type.intake_channel")}</h4>")
    end

    # IntakeChannel.default falls back to the first channel, so a report only lacks one when it was
    # created before any channel existed.
    it "lists a configured channel that has no reports at all" do
      create(:deficiency_report, category: category, intake_channel: nil)
      create(:deficiency_report_intake_channel, name: "Persoenlich")

      get adm_deficiency_reports_stats_path

      expect(response.body).to include("Persoenlich")
    end

    it "groups reports without a channel under a channel-specific label" do
      create(:deficiency_report, category: category, intake_channel: nil)
      create(:deficiency_report_intake_channel, name: "Telefon")

      get adm_deficiency_reports_stats_path

      expect(response.body).to include(row_named("without.intake_channel"))
    end

    it "carries the satisfaction ratings, like the category and case worker tables" do
      channel = create(:deficiency_report_intake_channel, name: "Telefon")
      report = create(:deficiency_report, category: category, intake_channel: channel)
      DeficiencyReport::FeedbackForm.create!(
        deficiency_report: report,
        overall_satisfaction: 4,
        response_time_satisfaction: 5,
        communication_satisfaction: 4
      )

      get adm_deficiency_reports_stats_path

      expect(response.body).to match(
        />#{stats_label("type.intake_channel")}<\/h4>.*?adm-metric-row__satisfaction/m
      )
    end
  end

  describe "the groups a dimension does not cover" do
    it "gives unassigned reports a row of their own, not the status label" do
      create(:deficiency_report, category: category, responsible: nil)

      get adm_deficiency_reports_stats_path

      expect(response.body).to include(row_named("without.responsible"))
      expect(response.body).not_to include(row_named("without.status"))
    end

    it "omits the row when every report is covered" do
      officer = create(:deficiency_report_officer)
      create(:deficiency_report, category: category, responsible: officer)

      get adm_deficiency_reports_stats_path

      expect(response.body).not_to include(row_named("without.responsible"))
    end
  end
end
