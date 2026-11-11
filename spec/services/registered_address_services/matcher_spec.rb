require "rails_helper"

describe RegisteredAddressServices::Matcher do
  def match(street_address, plz: "51147", city_name: "Köln")
    described_class.call(street_address: street_address, plz: plz, city_name: city_name)
  end

  let!(:heidestrasse) do
    create(:registered_address, street_name: "Heidestraße", street_number: "17", plz: "51147", city_name: "Köln")
  end

  describe "a matching address" do
    it "links the register entry and takes over the register's spelling" do
      expect(match("HEIDESTRASSE, 17", city_name: "KÖLN")).to eq(
        registered_address_id: heidestrasse.id,
        street_name: "Heidestraße",
        street_number: "17",
        street_number_extension: nil,
        plz: "51147",
        city_name: "Köln"
      )
    end

    it "treats str. and straße as the same street" do
      expect(match("Heidestr. 17")[:registered_address_id]).to eq(heidestrasse.id)
    end

    it "treats an abbreviated register name and a spelled-out address as the same street" do
      abbreviated = create(:registered_address, street_name: "Frankfurter Str.", street_number: "33",
                                                plz: "51147", city_name: "Köln")

      expect(match("Frankfurter Straße 33")[:registered_address_id]).to eq(abbreviated.id)
    end

    it "treats hyphens and spaces in the street name as the same" do
      hyphenated = create(:registered_address, street_name: "Theodor-Heuss-Straße", street_number: "1",
                                               plz: "51147", city_name: "Köln")

      expect(match("Theodor Heuss Strasse 1")[:registered_address_id]).to eq(hyphenated.id)
    end

    it "matches the house number suffix regardless of case and spacing" do
      with_suffix = create(:registered_address, street_name: "Heidestraße", street_number: "17",
                                                street_number_extension: "a", plz: "51147", city_name: "Köln")

      expect(match("Heidestraße 17 A")[:registered_address_id]).to eq(with_suffix.id)
    end

    it "treats ß and ss in the city name as the same" do
      in_unterschleissheim = create(:registered_address, street_name: "Ahornstraße", street_number: "1",
                                                         plz: "85716", city_name: "Unterschleißheim")

      result = match("Ahornstraße 1", plz: "85716", city_name: "UNTERSCHLEISSHEIM")

      expect(result[:registered_address_id]).to eq(in_unterschleissheim.id)
      expect(result[:city_name]).to eq("Unterschleißheim")
    end
  end

  describe "the same street in several villages of one municipality" do
    let!(:in_dattenberg) do
      create(:registered_address, street_name: "Bergstraße", street_number: "10", plz: "53547", city_name: "Dattenberg")
    end
    let!(:in_kasbach) do
      create(:registered_address, street_name: "Bergstraße", street_number: "10", plz: "53547",
                                  city_name: "Kasbach-Ohlenberg")
    end

    it "lets the city decide" do
      expect(match("Bergstraße 10", plz: "53547", city_name: "Kasbach-Ohlenberg")[:registered_address_id])
        .to eq(in_kasbach.id)
      expect(match("Bergstraße 10", plz: "53547", city_name: "dattenberg")[:registered_address_id])
        .to eq(in_dattenberg.id)
    end

    it "does not link a village that is not in the register" do
      expect(match("Bergstraße 10", plz: "53547", city_name: "Linz")[:registered_address_id]).to be_nil
    end
  end

  describe "an address that is not in the register" do
    it "returns the received address without a link, each word capitalized" do
      expect(match("THEODOR-HEUSS-STRASSE 1B", plz: "53757", city_name: "SANKT AUGUSTIN")).to eq(
        registered_address_id: nil,
        street_name: "Theodor-Heuss-Strasse",
        street_number: "1",
        street_number_extension: "B",
        plz: "53757",
        city_name: "Sankt Augustin"
      )
    end

    it "does not link a house number the register does not have" do
      expect(match("Heidestraße 99")[:registered_address_id]).to be_nil
    end

    it "does not link a missing suffix to an address that has one" do
      create(:registered_address, street_name: "Gartenweg", street_number: "3", street_number_extension: "a",
                                  plz: "51147", city_name: "Köln")

      expect(match("Gartenweg 3")[:registered_address_id]).to be_nil
    end

    it "does not link a matching street under another postal code" do
      expect(match("Heidestraße 17", plz: "50667")[:registered_address_id]).to be_nil
    end

    it "does not link an address without a city" do
      expect(match("Heidestraße 17", city_name: "")[:registered_address_id]).to be_nil
    end

    it "keeps a street without a house number as the street name" do
      result = match("Heidestraße")

      expect(result[:registered_address_id]).to be_nil
      expect(result[:street_name]).to eq("Heidestraße")
      expect(result[:street_number]).to be_nil
    end
  end
end
