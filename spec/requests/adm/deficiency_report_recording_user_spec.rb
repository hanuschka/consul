require "rails_helper"

describe "Crediting the staff member who recorded a report", type: :request do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:category) { create(:deficiency_report_category) }
  let(:map_location_attributes) do
    { latitude: 50.7956, longitude: 7.2044, zoom: 12, rendering_library: "leaflet" }
  end

  def show_label(key)
    I18n.t("adm.deficiency_reports.deficiency_reports.show.#{key}")
  end

  def detail_values
    response.body.scan(/<div class="adm-detail-table__value">(.*?)<\/div>/m).flatten.map(&:strip)
  end

  def detail_row(label)
    pattern = /adm-detail-table__label">#{Regexp.escape(label)}<\/div>\s*
               <div\ class="adm-detail-table__value">(.*?)<\/div>/xm

    response.body[pattern, 1]&.strip
  end

  def record_in_backend(**on_behalf_of_attributes)
    post adm_deficiency_reports_deficiency_reports_path, params: {
      deficiency_report: {
        title: "Broken street lamp",
        description: "A resident called about a lamp that stays dark.",
        deficiency_report_category_id: category.id,
        map_location_attributes: map_location_attributes
      }.merge(on_behalf_of_attributes)
    }
  end

  before do
    create(:deficiency_report_status)
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  describe "recording a report in the backend on behalf of a citizen" do
    before { login_as(manager) }

    it "fills all three fields: the account, the typed name and the colleague" do
      create(:user, username: "mmuster", email: "erika@example.org")

      record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")

      get adm_deficiency_reports_deficiency_report_path(DeficiencyReport.last)

      expect(detail_row(show_label("author"))).to eq("mmuster")
      expect(detail_row(show_label("on_behalf_of_label"))).to eq("Erika Mustermann")
      expect(detail_row(show_label("recorded_by_label"))).to eq(manager.username)
    end

    it "stores the logged-in staff member as the recording user" do
      record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")

      expect(DeficiencyReport.last.recorded_by).to eq(manager)
    end

    it "still attributes the report to the citizen account found or created from the address" do
      record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")

      citizen = User.find_by(email: "erika@example.org")

      expect(citizen).to be_present
      expect(DeficiencyReport.last.author).to eq(citizen)
    end

    it "attributes it to the account that address already had, without a second account mail" do
      existing = create(:user, email: "erika@example.org")

      expect do
        record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")
      end.not_to change(User, :count)

      report = DeficiencyReport.last

      expect(report.author).to eq(existing)
      expect(report.recorded_by).to eq(manager)
      expect(enqueued_jobs.select { |job| job[:args].to_s.include?("account_created") }).to be_empty
    end

    it "still produces the account mail for an address that had no account" do
      expect do
        record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")
      end.to have_enqueued_mail(OnBehalfOfAccountMailer, :account_created)
    end

    it "shows the company and the email address of the person it was recorded for" do
      record_in_backend(
        on_behalf_of: "Erika Mustermann",
        on_behalf_of_email: "erika@example.org",
        on_behalf_of_company_name: "Musterbau GmbH"
      )

      get adm_deficiency_reports_deficiency_report_path(DeficiencyReport.last)

      expect(detail_row(show_label("author"))).to eq("Erika Mustermann")
      expect(detail_row(show_label("on_behalf_of_company_label"))).to eq("Musterbau GmbH")
      expect(detail_row(show_label("on_behalf_of_email_label"))).to eq("erika@example.org")
    end

    it "omits the company row when no company was entered" do
      record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")

      get adm_deficiency_reports_deficiency_report_path(DeficiencyReport.last)

      expect(detail_row(show_label("on_behalf_of_company_label"))).to be_nil
      expect(detail_row(show_label("on_behalf_of_email_label"))).to eq("erika@example.org")
    end

    it "omits Im Auftrag von when the account carries the same name, rather than repeating it" do
      record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@example.org")

      report = DeficiencyReport.last
      expect(report.author.username).to eq("Erika Mustermann")

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(detail_row(show_label("author"))).to eq("Erika Mustermann")
      expect(detail_row(show_label("on_behalf_of_label"))).to be_nil
      expect(detail_values.count("Erika Mustermann")).to eq(1)
    end

    it "keeps the typed name when no email was entered, with no company or email row" do
      record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_company_name: "Musterbau GmbH")

      report = DeficiencyReport.last
      expect(report.author).to eq(manager)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(detail_row(show_label("author"))).to eq(manager.username)
      expect(detail_row(show_label("on_behalf_of_label"))).to eq("Erika Mustermann")
      expect(detail_row(show_label("recorded_by_label"))).to be_nil
      expect(detail_row(show_label("on_behalf_of_company_label"))).to be_nil
      expect(detail_row(show_label("on_behalf_of_email_label"))).to be_nil
    end
  end

  describe "a report a citizen submitted themselves" do
    let(:citizen) { create(:user) }

    before do
      set_setting("process.deficiency_reports", true)
      set_setting("deficiency_reports.show_create_report_button", true)
      login_as(citizen)
    end

    it "stores no recording user" do
      post deficiency_reports_path, params: {
        deficiency_report: {
          deficiency_report_category_id: category.id,
          resource_terms: "1",
          translations_attributes: {
            "0" => { locale: "en", title: "Pothole on Main Street", description: "It keeps growing." }
          },
          map_location_attributes: map_location_attributes
        }
      }

      report = DeficiencyReport.last

      expect(report.recorded_by).to be_nil
      expect(report.author).to eq(citizen)
    end

    it "stores no recording user even if an address is smuggled into the request" do
      post deficiency_reports_path, params: {
        deficiency_report: {
          deficiency_report_category_id: category.id,
          resource_terms: "1",
          on_behalf_of_email: "someone.else@example.org",
          translations_attributes: {
            "0" => { locale: "en", title: "Pothole on Main Street", description: "It keeps growing." }
          },
          map_location_attributes: map_location_attributes
        }
      }

      report = DeficiencyReport.last

      expect(report.author).to eq(citizen)
      expect(report.recorded_by).to be_nil
      expect(User.find_by(email: "someone.else@example.org")).to be_nil
    end

    it "shows the submitter under Autor, and neither the company nor the email row" do
      report = create(:deficiency_report, author: citizen)
      login_as(manager)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(detail_row(show_label("author"))).to eq(citizen.username)
      expect(detail_row(show_label("on_behalf_of_label"))).to be_nil
      expect(detail_row(show_label("recorded_by_label"))).to be_nil
      expect(detail_row(show_label("on_behalf_of_company_label"))).to be_nil
      expect(detail_row(show_label("on_behalf_of_email_label"))).to be_nil
    end
  end

  describe "the public form no longer accepts on-behalf-of data" do
    before do
      set_setting("process.deficiency_reports", true)
      set_setting("deficiency_reports.show_create_report_button", true)
      login_as(manager)
    end

    it "ignores the fields even for a manager, so recording for somebody stays an /adm job" do
      post deficiency_reports_path, params: {
        deficiency_report: {
          deficiency_report_category_id: category.id,
          resource_terms: "1",
          on_behalf_of: "Erika Mustermann",
          on_behalf_of_email: "erika@example.org",
          on_behalf_of_company_name: "Musterbau GmbH",
          translations_attributes: {
            "0" => { locale: "en", title: "Pothole on Main Street", description: "It keeps growing." }
          },
          map_location_attributes: map_location_attributes
        }
      }

      report = DeficiencyReport.last

      expect(report.author).to eq(manager)
      expect(report.on_behalf_of).to be_nil
      expect(report.recorded_by).to be_nil
      expect(User.find_by(email: "erika@example.org")).to be_nil
    end

    it "does not render the on-behalf-of fields on the form" do
      get new_deficiency_report_path

      expect(response.body).not_to include("deficiency_report[on_behalf_of]")
      expect(response.body).not_to include("deficiency_report[on_behalf_of_email]")
      expect(response.body).not_to include("deficiency_report[deficiency_report_intake_channel_id]")
    end
  end

  describe "the other on-behalf-of models" do
    it "cannot be given a recording user, so they keep crediting the citizen" do
      recordable = [Proposal, Budget::Investment, Idea].select do |model|
        model.new.respond_to?(:recorded_by=)
      end

      expect(recordable).to be_empty
    end

    # invisible_captcha rejects a POST whose session carries no timestamp, and the timestamp is
    # only planted by rendering the proposal form. This example posts to the endpoint directly.
    around do |example|
      InvisibleCaptcha.timestamp_enabled = false
      example.run
      InvisibleCaptcha.timestamp_enabled = true
    end

    it "keeps crediting the citizen on a proposal recorded on behalf of someone" do
      admin = create(:administrator).user
      projekt_phase = create(:projekt_phase)
      login_as(admin)

      post proposals_path, params: {
        proposal: {
          projekt_phase_id: projekt_phase.id,
          responsible_name: "Erika Mustermann",
          resource_terms: "1",
          on_behalf_of: "Erika Mustermann",
          on_behalf_of_email: "erika@example.org",
          translations_attributes: {
            "0" => {
              locale: "en",
              title: "A bench by the river",
              description: "There is nowhere to sit along the path."
            }
          }
        }
      }

      proposal = Proposal.last
      citizen = User.find_by(email: "erika@example.org")

      expect(citizen).to be_present
      expect(proposal.author).to eq(citizen)
      expect(proposal.author_name).to eq("Erika Mustermann")
    end
  end

  describe "the reports overview" do
    let(:citizen) { create(:user, username: "mmuster") }
    let!(:report) do
      create(:deficiency_report, author: citizen, recorded_by: manager, on_behalf_of: "Erika Mustermann")
    end

    before { login_as(manager) }

    def cell(field)
      response.body[/<td[^>]*data-field="#{field}".*?<\/td>/m]
    end

    it "gives the account, the typed name and the colleague a column each" do
      get adm_deficiency_reports_deficiency_reports_list_path

      expect(cell("author")).to include("mmuster")
      expect(cell("on_behalf_of")).to include("Erika Mustermann")
      expect(cell("recorded_by")).to include(manager.username)
    end

    it "carries a header for the on-behalf column so the column selector can hide it" do
      get adm_deficiency_reports_deficiency_reports_list_path

      expect(response.body).to match(/<th[^>]*data-field="on_behalf_of"/)
    end

    it "leaves Erfasst von empty for a report nobody recorded in the backend" do
      report.update!(recorded_by: nil)

      get adm_deficiency_reports_deficiency_reports_list_path

      expect(cell("recorded_by")).to be_present
      expect(cell("recorded_by")).not_to include(manager.username)
    end

    it "leaves Im Auftrag von empty when the account carries the same name" do
      report.update!(on_behalf_of: citizen.username)

      get adm_deficiency_reports_deficiency_reports_list_path

      expect(cell("author")).to include(citizen.username)
      expect(cell("on_behalf_of")).to be_present
      expect(cell("on_behalf_of")).not_to include(citizen.username)
    end

    it "leaves Erfasst von empty when the recorder is the author, rather than repeating them" do
      report.update!(author: manager, recorded_by: manager)

      get adm_deficiency_reports_deficiency_reports_list_path

      expect(cell("author")).to include(manager.username)
      expect(cell("recorded_by")).to be_present
      expect(cell("recorded_by")).not_to include(manager.username)
    end

    it "carries a header for the Erfasst von column so the column selector can hide it" do
      get adm_deficiency_reports_deficiency_reports_list_path

      expect(response.body).to match(/<th[^>]*data-field="recorded_by"/)
    end

    it "searches Autor by the account username the column shows" do
      get adm_deficiency_reports_deficiency_reports_list_path,
          params: { author__search: "mmuster" }

      expect(response.body).to include(report.title)
    end

    it "does not answer an Autor search with the typed name, which is its own column" do
      get adm_deficiency_reports_deficiency_reports_list_path,
          params: { author__search: "Erika" }

      expect(response.body).not_to include(report.title)
    end

    it "searches Im Auftrag von by the typed name" do
      get adm_deficiency_reports_deficiency_reports_list_path,
          params: { on_behalf_of__search: "Erika" }

      expect(response.body).to include(report.title)
    end

    it "does not answer an Im Auftrag von search with the account username" do
      get adm_deficiency_reports_deficiency_reports_list_path,
          params: { on_behalf_of__search: "mmuster" }

      expect(response.body).not_to include(report.title)
    end

    it "does not match an unrelated name" do
      get adm_deficiency_reports_deficiency_reports_list_path,
          params: { author__search: "Nobody At All" }

      expect(response.body).not_to include(report.title)
    end
  end

  describe "exports" do
    let(:citizen) { create(:user, username: "mmuster") }
    let(:report) do
      create(:deficiency_report, author: citizen, recorded_by: manager, on_behalf_of: "Erika Mustermann")
    end

    it "gives the account, the typed name and the colleague a CSV column each" do
      csv = CSV.parse(CsvServices::DeficiencyReportsExporter.call([report]), col_sep: ";", headers: true)

      expect(csv.first["Autor"]).to eq("mmuster")
      expect(csv.first["Meldung im Namen von"]).to eq("Erika Mustermann")
      expect(csv.first["Erfasst von"]).to eq(manager.username)
    end

    it "leaves Erfasst von blank in the CSV for a report nobody recorded in the backend" do
      legacy = create(:deficiency_report, author: citizen)

      csv = CSV.parse(CsvServices::DeficiencyReportsExporter.call([legacy]), col_sep: ";", headers: true)

      expect(csv.first["Autor"]).to eq(citizen.username)
      expect(csv.first["Erfasst von"]).to be_blank
    end

    it "leaves Erfasst von blank in the CSV when the recorder is the author" do
      own = create(:deficiency_report, author: manager, recorded_by: manager)

      csv = CSV.parse(CsvServices::DeficiencyReportsExporter.call([own]), col_sep: ";", headers: true)

      expect(csv.first["Autor"]).to eq(manager.username)
      expect(csv.first["Erfasst von"]).to be_blank
    end

    it "leaves the company and the email out of the CSV, as the ticket asks" do
      csv = CSV.parse(CsvServices::DeficiencyReportsExporter.call([report]), col_sep: ";", headers: true)

      expect(csv.headers).not_to include(
        show_label("on_behalf_of_company_label"), show_label("on_behalf_of_email_label"), "Firma", "E-Mail"
      )
    end

    it "appends Erfasst von after the existing columns rather than shifting them" do
      csv = CSV.parse(CsvServices::DeficiencyReportsExporter.call([report]), col_sep: ";", headers: true)

      expect(csv.headers.first(3)).to eq(["ID", "Sichtbarkeit", "Autor"])
      expect(csv.headers.index("Erfasst von")).to be > csv.headers.index("Meldung im Namen von")
    end

    it "carries all three names in the PDF meta rows" do
      rows = PdfServices::DeficiencyReportExporter.new(report, "example.org").send(:meta_rows)

      expect(rows).to include([show_label("author"), citizen.username])
      expect(rows).to include([show_label("on_behalf_of_label"), "Erika Mustermann"])
      expect(rows).to include([show_label("recorded_by_label"), manager.username])
    end

    it "omits the PDF Erfasst von row for a report nobody recorded in the backend" do
      legacy = create(:deficiency_report, author: citizen)

      rows = PdfServices::DeficiencyReportExporter.new(legacy, "example.org").send(:meta_rows)

      expect(rows.map(&:first)).not_to include(show_label("recorded_by_label"))
    end

    it "omits the PDF Im Auftrag von row when the account carries the same name" do
      same = create(:deficiency_report, author: citizen, recorded_by: manager,
                                        on_behalf_of: citizen.username)

      rows = PdfServices::DeficiencyReportExporter.new(same, "example.org").send(:meta_rows)

      expect(rows.map(&:first)).not_to include(show_label("on_behalf_of_label"))
    end

    it "omits the PDF Erfasst von row when the recorder is the author" do
      own = create(:deficiency_report, author: manager, recorded_by: manager)

      rows = PdfServices::DeficiencyReportExporter.new(own, "example.org").send(:meta_rows)

      expect(rows.map(&:first)).not_to include(show_label("recorded_by_label"))
    end
  end
end
