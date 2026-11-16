require "rails_helper"

describe "Offer import in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def upload(content)
    file = Tempfile.new(["angebote", ".csv"])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  end

  def csv_with(*rows)
    columns = Offers::CsvImport::COLUMNS
    CSV.generate(col_sep: ";") do |csv|
      csv << Offers::CsvImport.headers
      rows.each { |row| csv << columns.map { |column| row[column] } }
    end
  end

  context "as an administrator" do
    before { login_as(admin) }

    it "shows the upload page" do
      get new_adm_offers_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(template_adm_offers_import_path)
    end

    it "imports the valid rows and lists the failing ones with their reason" do
      create(:offer_provider, name: "Sportverein Nord")
      create(:offer_category, :offer_type, name: "Sportkurs")
      create(:offer_category, :social_area, name: "Nord")
      valid = { provider: "Sportverein Nord", short_description: "Für Kinder",
                offer_type: "Sportkurs", social_area: "Nord" }

      post adm_offers_import_path, params: { file: upload(csv_with(valid.merge(title: "Schwimmen"),
                                                                   valid.merge(title: "Laufen", provider: "Unbekannt"))) }

      expect(response).to have_http_status(:ok)
      expect(Offer.count).to eq 1
      expect(response.body).to include("Schwimmen", edit_adm_offers_offer_path(Offer.last))
      expect(response.body).to include("Laufen",
                                       CGI.escapeHTML(I18n.t("adm.offers.imports.errors.unknown_provider", name: "Unbekannt")))
    end

    it "asks for a file when none is chosen" do
      post adm_offers_import_path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("adm.offers.imports.create.no_file"))
    end

    it "downloads the template" do
      get template_adm_offers_import_path

      expect(response.media_type).to eq "text/csv"
      expect(response.body).to include(*Offers::CsvImport.headers)
    end
  end

  context "as another user" do
    before { login_as(create(:user)) }

    it "cannot import offers" do
      post adm_offers_import_path, params: { file: upload("x") }

      expect(response).to redirect_to(adm_root_path)
      expect(Offer.count).to eq 0
    end
  end
end
