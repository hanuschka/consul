require "rails_helper"

describe Offers::CsvExport do
  let(:admin) { create(:administrator).user }
  let!(:provider) { create(:offer_provider, name: "Sportverein Nord") }
  let!(:offer_type) { create(:offer_category, :offer_type, name: "Sportkurs") }
  let!(:north) { create(:offer_category, :social_area, name: "Nord") }
  let!(:south) { create(:offer_category, :social_area, name: "Süd") }

  def parse(content)
    CSV.parse(content.delete_prefix("﻿"), col_sep: ";", headers: true)
  end

  def column(key)
    I18n.t("adm.offers.imports.columns.#{key}", locale: I18n.default_locale)
  end

  def create_full_offer
    offer = create(:offer, title: "Schwimmen", provider: provider, categories: [offer_type, north, south],
                           short_description: "<p>Für Kinder &amp; Eltern</p><p>Zweiter Absatz</p>",
                           expires_on: Date.new(2027, 12, 31))
    offer.create_map_location!(
      latitude: 1.0, longitude: 1.0, zoom: 15, skip_masterportal_geocoding: true,
      features: { type: "FeatureCollection",
                  features: [{ type: "Feature", geometry: { type: "Point", coordinates: [10.4515, 51.1657] },
                               properties: {} }] }
    )
    offer
  end

  it "writes the ID, the import columns, the check status and the visibility" do
    offer = create_full_offer
    offer.suspend!

    table = parse(described_class.call(Offer.where(id: offer.id)))
    row = table.first

    expect(table.headers).to eq [Offers::CsvImport.id_header] + Offers::CsvImport.headers +
                                %w[review_status visibility].map { |key|
                                  I18n.t("adm.offers.offers.index.table.#{key}", locale: I18n.default_locale)
                                }
    expect(row[column(:provider)]).to eq "Sportverein Nord"
    expect(row[column(:short_description)]).to eq "Für Kinder & Eltern\n\nZweiter Absatz"
    expect(row[column(:social_area)].split(", ")).to match_array %w[Nord Süd]
    expect(row[column(:expires_on)]).to eq "31.12.2027"
    expect([row[column(:latitude)], row[column(:longitude)]]).to eq %w[51,1657 10,4515]
    expect(row["ID"]).to eq offer.id.to_s
    expect(row.fields.last).to eq I18n.t("adm.offers.offers.index.visibility.suspended", locale: I18n.default_locale)
  end

  it "produces a file the import reads back as a new offer once the ID column is removed" do
    original = create_full_offer
    table = parse(described_class.call(Offer.where(id: original.id)))
    without_id = CSV.generate(col_sep: ";") do |csv|
      csv << table.headers.drop(1)
      table.each { |row| csv << row.fields.drop(1) }
    end

    result = Offers::CsvImport.call(without_id, author: admin)

    expect(result.rows.map(&:errors)).to all(be_empty)
    copy = result.rows.first.offer.reload
    expect(copy.title).to eq original.title
    expect(copy.provider).to eq provider
    expect(copy.categories).to match_array [offer_type, north, south]
    expect(copy.expires_on).to eq original.expires_on
    expect(copy.map_location.pin_coordinates).to eq original.map_location.pin_coordinates
    expect(copy.short_description).to include("Für Kinder &amp; Eltern", "Zweiter Absatz")
  end

  describe "importing the export again" do
    def edited_export(offers)
      table = parse(described_class.call(offers))
      table.each { |row| yield row } if block_given?
      table.to_csv(col_sep: ";")
    end

    it "leaves unchanged offers alone" do
      original = create_full_offer
      original.update_columns(updated_at: 2.days.ago)

      result = Offers::CsvImport.call(edited_export(Offer.all), author: admin)

      expect(result.rows.map(&:status)).to eq [:unchanged]
      expect(Offer.count).to eq 1
      expect(original.reload.updated_at).to be < 1.day.ago
    end

    it "updates the offer of a row with its ID" do
      original = create_full_offer
      original.update!(short_description: "<p>Für <strong>Kinder</strong></p>", times: "montags")
      original.suspend!

      result = Offers::CsvImport.call(edited_export(Offer.all) { |row|
        row[column(:title)] = "Schwimmen für alle"
        row[column(:times)] = ""
        row[column(:social_area)] = "Süd"
        row[column(:latitude)] = ""
        row[column(:longitude)] = ""
      }, author: admin)

      expect(result.rows.map(&:status)).to eq [:updated]
      expect(Offer.count).to eq 1
      original.reload
      expect(original.title).to eq "Schwimmen für alle"
      expect(original.times).to be_blank
      expect(original.categories).to match_array [offer_type, south]
      expect(original.map_location).to be_nil
      expect(original.short_description).to eq "<p>Für <strong>Kinder</strong></p>"
      expect(original).to be_suspended
      expect(original).to be_review_checked
    end

    it "refuses a row whose ID belongs to no offer" do
      create_full_offer

      content = edited_export(Offer.all) { |row| row["ID"] = "999999" }
      result = Offers::CsvImport.call(content, author: admin)

      expect(result.rows.first.errors).to eq [I18n.t("adm.offers.imports.errors.unknown_offer", id: "999999")]
      expect(Offer.count).to eq 1
    end
  end
end
