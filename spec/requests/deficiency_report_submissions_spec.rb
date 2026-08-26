require "rails_helper"
require "cancan/matchers"

describe "Deficiency report submissions", type: :request do
  let!(:officer)  { create(:deficiency_report_officer) }
  let!(:category) { create(:deficiency_report_category, default_responsible: officer) }
  let(:user)      { create(:user) }

  let(:confirmation_popup) do
    DeficiencyReport::ConfirmationPopup.current.tap do |popup|
      popup.update!(enabled: true, question: "Is this about a public space?")
      popup.answers.create!(label: "Yes, continue", behavior: :allow)
    end
  end

  let(:map_location_attributes) do
    { latitude: 50.7956, longitude: 7.2044, zoom: 12, rendering_library: "leaflet" }
  end

  let(:submission_params) do
    {
      deficiency_report: {
        deficiency_report_category_id: category.id,
        resource_terms: "1",
        translations_attributes: {
          "0" => {
            locale: "en",
            title: "Pothole on Main Street",
            description: "The hole gets deeper every week."
          }
        },
        map_location_attributes: map_location_attributes
      }
    }
  end

  before do
    create(:deficiency_report_status)
    set_setting("process.deficiency_reports", true)
    set_setting("deficiency_reports.create_cta", "Report something now")
    allow(Geocoder).to receive(:search).and_return([])
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  context "while submissions are closed" do
    before { set_setting("deficiency_reports.show_create_report_button", false) }

    describe "GET /deficiency_reports/new" do
      it "sends a logged-in user back to the overview with a notice" do
        login_as(user)

        get new_deficiency_report_path

        expect(response).to redirect_to(deficiency_reports_path)
        expect(flash[:notice]).to eq(I18n.t("custom.deficiency_reports.submissions_closed"))
      end

      it "sends an anonymous visitor there too, without a detour through the login" do
        get new_deficiency_report_path

        expect(response).to redirect_to(deficiency_reports_path)
        expect(flash[:notice]).to eq(I18n.t("custom.deficiency_reports.submissions_closed"))
      end

      it "does not authorize creating a report at all" do
        expect(Ability.new(user)).not_to be_able_to(:create, DeficiencyReport)
        expect(Ability.new(user)).not_to be_able_to(:new, DeficiencyReport)
      end
    end

    describe "POST /deficiency_reports" do
      it "creates no report, assigns nobody and mails nobody" do
        login_as(user)

        post deficiency_reports_path, params: submission_params

        expect(response).to redirect_to(deficiency_reports_path)
        expect(DeficiencyReport.count).to eq(0)
        expect(DeficiencyReport.assigned).to be_empty
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    describe "GET /deficiency_reports" do
      it "renders no submit button in the new design" do
        get deficiency_reports_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Report something now")
        expect(response.body).not_to include(new_deficiency_report_path)
      end

      it "renders no submit button in the old design" do
        allow(Setting).to receive(:new_design_enabled?).and_return(false)

        get deficiency_reports_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Report something now")
        expect(response.body).not_to include(new_deficiency_report_path)
      end

      it "renders no confirmation popup, which carries links to the form of its own" do
        confirmation_popup

        get deficiency_reports_path

        expect(response.body).not_to include("Is this about a public space?")
        expect(response.body).not_to include("Yes, continue")
        expect(response.body).not_to include(new_deficiency_report_path)
      end
    end

    describe "GET /" do
      it "renders no homepage call to action even while it is switched on" do
        set_setting("deficiency_reports.show_homepage_cta", true)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Report something now")
      end
    end

    describe "POST /adm/deficiency_reports" do
      let(:manager) { create(:user) }

      before { DeficiencyReportManager.create!(user: manager) }

      it "still records a report filed from the back office" do
        login_as(manager)

        expect do
          post adm_deficiency_reports_deficiency_reports_path, params: {
            deficiency_report: {
              title: "Broken street lamp",
              description: "A resident called about a lamp that stays dark.",
              deficiency_report_category_id: category.id,
              map_location_attributes: map_location_attributes
            }
          }
        end.to change(DeficiencyReport, :count).by(1)

        expect(response).to redirect_to(
          adm_deficiency_reports_deficiency_report_path(DeficiencyReport.last)
        )
      end
    end
  end

  context "while submissions are open" do
    before { set_setting("deficiency_reports.show_create_report_button", true) }

    describe "GET /deficiency_reports/new" do
      it "opens the form" do
        login_as(user)

        get new_deficiency_report_path

        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /deficiency_reports" do
      it "creates the report, assigns the responsible officer and mails the author" do
        login_as(user)

        expect do
          post deficiency_reports_path, params: submission_params
        end.to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_submission)

        report = DeficiencyReport.last

        expect(DeficiencyReport.count).to eq(1)
        expect(response).to redirect_to(deficiency_report_path(report))
        expect(report.title).to eq("Pothole on Main Street")
        expect(report.responsible).to eq(officer)
      end
    end

    describe "GET /deficiency_reports" do
      it "renders the submit button in the new design" do
        get deficiency_reports_path

        expect(response.body).to include("Report something now")
      end

      it "renders the submit button in the old design" do
        allow(Setting).to receive(:new_design_enabled?).and_return(false)

        get deficiency_reports_path

        expect(response.body).to include("Report something now")
      end

      it "renders the confirmation popup" do
        confirmation_popup

        get deficiency_reports_path

        expect(response.body).to include("Is this about a public space?")
        expect(response.body).to include("Yes, continue")
        expect(response.body).to include(new_deficiency_report_path)
      end
    end

    describe "GET /" do
      it "renders the homepage call to action" do
        set_setting("deficiency_reports.show_homepage_cta", true)

        get root_path

        expect(response.body).to include("Report something now")
      end
    end
  end
end
