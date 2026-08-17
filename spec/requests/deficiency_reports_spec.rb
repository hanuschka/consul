require "rails_helper"

# The public overview and the public page deliberately disagree about an author's own pending
# Anliegen: Abilities::Common admits the author to their own report with a rule of its own, and
# DeficiencyReportsController#index then narrows the accessible scope with `.admin_accepted` a second
# time, so nothing pending reaches the public list — not even its author's own copy.
#
# The rule matrix behind this lives in spec/models/ability/deficiency_report_visibility_spec.rb.
# This file exercises the two endpoints, which is where the second narrowing happens.
describe "Deficiency report visibility", type: :request do
  # Titles that are not substrings of one another, so asserting one is absent from the rendered
  # page cannot be satisfied or broken by the other.
  let!(:pending_report) { create(:deficiency_report, title: "Pothole on Main Street") }
  let!(:accepted_report) do
    create(:deficiency_report, title: "Broken bench in the park", admin_accepted: true)
  end
  let(:author)   { pending_report.author }
  let(:stranger) { create(:user) }

  before { set_setting("process.deficiency_reports", true) }

  def listed_reports
    controller.view_assigns["deficiency_reports"].to_a
  end

  context "while admin acceptance is required" do
    before { set_setting("deficiency_reports.admin_acceptance_required", true) }

    describe "GET /deficiency_reports" do
      it "leaves the author's own pending report out of the list" do
        login_as(author)

        get deficiency_reports_path

        expect(response).to have_http_status(:ok)
        expect(listed_reports).to eq([accepted_report])
        expect(response.body).to include(accepted_report.title)
        expect(response.body).not_to include(pending_report.title)
      end

      it "leaves it out for another logged-in user" do
        login_as(stranger)

        get deficiency_reports_path

        expect(listed_reports).to eq([accepted_report])
        expect(response.body).not_to include(pending_report.title)
      end

      it "leaves it out for an anonymous visitor" do
        get deficiency_reports_path

        expect(listed_reports).to eq([accepted_report])
        expect(response.body).not_to include(pending_report.title)
      end
    end

    describe "GET /deficiency_reports/:id" do
      # The other half of the asymmetry: the page the list refuses to link still opens for its author,
      # which is what the pending notice on it is for.
      it "opens the author's own pending report" do
        login_as(author)

        get deficiency_report_path(pending_report)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(pending_report.title)
      end

      it "refuses another logged-in user" do
        login_as(stranger)

        get deficiency_report_path(pending_report)

        expect(response).to redirect_to(root_path)
      end

      it "refuses an anonymous visitor" do
        get deficiency_report_path(pending_report)

        expect(response).to redirect_to(root_path)
      end

      it "opens an accepted report for anybody" do
        get deficiency_report_path(accepted_report)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  # The control: with acceptance not required there is nothing to disagree about, and both endpoints
  # treat the two reports alike.
  context "while admin acceptance is not required" do
    before { set_setting("deficiency_reports.admin_acceptance_required", false) }

    it "lists both reports for an anonymous visitor" do
      get deficiency_reports_path

      expect(listed_reports).to match_array([pending_report, accepted_report])
      expect(response.body).to include(pending_report.title, accepted_report.title)
    end

    it "opens the unaccepted report for an anonymous visitor" do
      get deficiency_report_path(pending_report)

      expect(response).to have_http_status(:ok)
    end
  end
end
