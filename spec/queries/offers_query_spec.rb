require "rails_helper"

describe OffersQuery do
  let(:north) { create(:offer_category, :social_area, name: "Nord") }
  let(:south) { create(:offer_category, :social_area, name: "Süd") }
  let(:sport) { create(:offer_category, :offer_type, name: "Sportkurs") }
  let(:culture) { create(:offer_category, :offer_type, name: "Kultur") }
  let(:step_free) { create(:offer_category, :accessibility, name: "Stufenlos") }
  let(:quiet) { create(:offer_category, :accessibility, name: "Ruhiger Raum") }

  def results(**params)
    described_class.new(Offer.all, params).call.map(&:title)
  end

  it "combines the keyword with every filter" do
    create(:offer, title: "Schwimmen für Kinder", categories: [sport, north, step_free])
    create(:offer, title: "Schwimmen für Erwachsene", categories: [sport, south, step_free])
    create(:offer, title: "Schwimmen am Abend", categories: [sport, north, quiet])
    create(:offer, title: "Lesecafé", categories: [culture, north, step_free])

    expect(results(search: "Schwimmen", social_area: [north.id], accessibility: [step_free.id]))
      .to eq ["Schwimmen für Kinder"]
  end

  it "finds an offer in two Sozialräume by either of them" do
    create(:offer, title: "Stadtteilfest", categories: [culture, north, south])

    expect(results(social_area: [north.id])).to eq ["Stadtteilfest"]
    expect(results(social_area: [south.id])).to eq ["Stadtteilfest"]
  end

  it "widens the result with several values of one filter" do
    create(:offer, title: "Fußball", categories: [sport, north])
    create(:offer, title: "Theater", categories: [culture, north])

    expect(results(offer_type: [sport.id, culture.id])).to match_array ["Fußball", "Theater"]
  end

  it "searches the texts, the address and the provider and needs every word" do
    provider = create(:offer_provider, name: "Sportverein Nord")
    create(:offer, title: "Training", times: "dienstags im Hallenbad", provider: provider)
    create(:offer, title: "Treffpunkt", address: "Marktplatz 1")
    create(:offer, title: "Malkurs", short_description: "<p>Aquarell und Öl</p>")

    expect(results(search: "hallenbad")).to eq ["Training"]
    expect(results(search: "sportverein")).to eq ["Training"]
    expect(results(search: "marktplatz")).to eq ["Treffpunkt"]
    expect(results(search: "aquarell öl")).to eq ["Malkurs"]
    expect(results(search: "aquarell hallenbad")).to be_empty
  end

  it "finds words with umlauts in a description the editor stored with HTML entities" do
    create(:offer, title: "Malkurs", short_description: "<p>Gr&ouml;&szlig;e egal &ndash; f&uuml;r alle</p>")

    expect(results(search: "Größe für")).to eq ["Malkurs"]
  end

  it "treats search wildcards as plain text" do
    create(:offer, title: "Schwimmen")

    expect(results(search: "%")).to be_empty
  end
end
