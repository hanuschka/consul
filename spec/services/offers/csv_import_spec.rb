require "rails_helper"

describe Offers::CsvImport do
  let(:admin) { create(:administrator).user }
  let!(:provider) { create(:offer_provider, name: "Sportverein Nord") }
  let!(:swimming) { create(:offer_category, :offer_type, name: "Sportkurs") }
  let!(:north) { create(:offer_category, :social_area, name: "Nord") }
  let!(:south) { create(:offer_category, :social_area, name: "Süd") }

  def headers
    described_class.headers
  end

  def csv(*rows, col_sep: ";")
    CSV.generate(col_sep: col_sep) do |file|
      file << headers
      rows.each { |row| file << described_class::COLUMNS.map { |column| row[column] } }
    end
  end

  def row(title, **overrides)
    { provider: "Sportverein Nord", title: title, short_description: "Für Kinder ab 6",
      offer_type: "Sportkurs", social_area: "Nord" }.merge(overrides)
  end

  def column_name(column)
    I18n.t("adm.offers.imports.columns.#{column}")
  end

  def import(content)
    described_class.call(content, author: admin)
  end

  it "creates the valid rows and names each failing row with the reason" do
    result = import(csv(row("Schwimmen"), row("Klettern"), row("Laufen", provider: "Unbekannt"),
                        row("Turnen")))

    expect(result.created_count).to eq 3
    expect(Offer.count).to eq 3
    failed = result.rows.select(&:failed?)
    expect(failed.map(&:line)).to eq [4]
    expect(failed.first.title).to eq "Laufen"
    expect(failed.first.errors).to eq [I18n.t("adm.offers.imports.errors.unknown_provider", name: "Unbekannt")]
  end

  it "fills the fields, categories and location of an offer" do
    import(csv(row("Schwimmen", times: "dienstags 15–17 Uhr", contact_email: "kurse@example.org",
                                social_area: "Nord, Süd", expires_on: "31.12.2027",
                                latitude: "50,9", longitude: "11,6",
                                short_description: "Erste Zeile\n\n<b>Zweite</b>")))

    offer = Offer.last
    expect(offer.title).to eq "Schwimmen"
    expect(offer.times).to eq "dienstags 15–17 Uhr"
    expect(offer.contact_email).to eq "kurse@example.org"
    expect(offer.provider).to eq provider
    expect(offer.author).to eq admin
    expect(offer.categories).to match_array [swimming, north, south]
    expect(offer.expires_on).to eq Date.new(2027, 12, 31)
    expect(offer.map_location.pin_coordinates).to eq(latitude: 50.9, longitude: 11.6)
    expect(offer.short_description).to eq "<p>Erste Zeile</p><p>&lt;b&gt;Zweite&lt;/b&gt;</p>"
    expect(offer).to be_review_checked
  end

  it "reports unknown category values, wrong dates and missing required fields" do
    result = import(csv(row("Schwimmen", social_area: "Mitte"),
                        row("Klettern", expires_on: "bald"),
                        row("", offer_type: "")))

    expect(result.created_count).to eq 0
    expect(result.rows[0].errors.join).to include("Mitte")
    expect(result.rows[1].errors.join).to include("bald")
    expect(result.rows[2].errors).to include(
      I18n.t("activerecord.errors.models.offer.category_required",
             category: I18n.t("activerecord.attributes.offer/category.kinds.offer_type"))
    )
  end

  it "reads comma-separated files and files saved by Excel in Windows-1252" do
    expect(import(csv(row("Schwimmen"), col_sep: ",")).created_count).to eq 1

    expect(import(csv(row("Süßwasser")).encode("Windows-1252")).created_count).to eq 1
    expect(Offer.last.title).to eq "Süßwasser"
  end

  it "rejects a file without the required columns" do
    result = import("Name;Beschreibung\nSchwimmen;Für Kinder\n")

    expect(result.rows).to be_empty
    expect(result.file_errors.join).to include(*described_class::REQUIRED_COLUMNS.map { |c| column_name(c) })
  end

  it "rejects a file with more rows than one request can import" do
    rows = Array.new(described_class::MAX_ROWS + 1) { |i| row("Angebot #{i}") }

    result = import(csv(*rows))

    expect(result.rows).to be_empty
    expect(result.file_errors).to eq [I18n.t("adm.offers.imports.errors.too_many_rows", max: described_class::MAX_ROWS)]
    expect(Offer.count).to eq 0
  end

  it "refuses a row without a provider" do
    result = import(csv(row("Schwimmen", provider: "")))

    expect(result.rows.first.errors).to eq [I18n.t("adm.offers.imports.errors.missing_provider")]
    expect(Offer.count).to eq 0
  end

  it "reads an export without offers as an empty file" do
    export = Offers::CsvExport.call(Offer.none)

    expect(CSV.parse_line(export.delete_prefix("\uFEFF"), col_sep: ";").first(headers.size + 1))
      .to eq [described_class.id_header] + headers
    expect(import(export).rows).to be_empty
  end

  describe "sample" do
    let(:sample_rows) { I18n.t("adm.offers.imports.sample_rows", locale: I18n.default_locale) }

    it "fills every column of the template in its first row" do
      rows = CSV.parse(described_class.sample.delete_prefix("﻿"), col_sep: ";")

      expect(rows.first).to eq headers
      expect(rows.size).to eq 3
      expect(rows.second).to all(be_present)
    end

    it "creates nothing while its placeholder provider does not exist" do
      result = import(described_class.sample)

      expect(result.rows.size).to eq 2
      expect(result.rows.map(&:errors)).to all(include(
        I18n.t("adm.offers.imports.errors.unknown_provider", name: sample_rows.first[:provider])
      ))
      expect(Offer.count).to eq 0
    end

    it "imports cleanly once its provider and categories exist" do
      create(:offer_provider, name: sample_rows.first[:provider])
      described_class::CATEGORY_COLUMNS.each do |column, kind|
        sample_rows.flat_map { |row| row[column].to_s.split(",").map(&:strip) }.compact_blank.uniq.each do |name|
          create(:offer_category, kind: kind, name: name)
        end
      end

      result = import(described_class.sample)

      expect(result.rows.map(&:errors)).to all(be_empty)
      expect(result.created_count).to eq 2
      expect(Offer.find_by!(expires_on: Date.new(2027, 12, 31)).map_location.pin_coordinates).to be_present
    end
  end
end
