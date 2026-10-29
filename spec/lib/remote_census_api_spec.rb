require "rails_helper"

describe RemoteCensusApi do
  describe RemoteCensusApi::Response do
    def registered_names(version, last_name:, particle:)
      if RemoteCensusApi::XmeldVersion.new(version).unstructured_names?
        <<~XML
          <ns2:familienname.unstrukturiert><ns2:nachname><name>#{last_name}</name></ns2:nachname></ns2:familienname.unstrukturiert>
          <ns2:vornamen><ns2:vornamen><name>Maria</name></ns2:vornamen></ns2:vornamen>
        XML
      else
        <<~XML
          <ns2:familienname>
            #{"<ns2:namensbestandteil>#{particle}</ns2:namensbestandteil>" if particle}
            <ns2:nachname>#{last_name}</ns2:nachname>
          </ns2:familienname>
          <ns2:vornamen><name>Maria</name></ns2:vornamen>
        XML
      end
    end

    def registry_answer(version:, entered_number:, entered_suffix:, registered_number:, registered_suffix:,
                        entered_last_name:, registered_last_name:, registered_particle:,
                        entered_street:, registered_street:)
      <<~XML
        <root xmlns:ns2="#{RemoteCensusApi::XmeldVersion.new(version).namespace}">
          <ns2:ergebnisstatus><code>01</code></ns2:ergebnisstatus>
          <ns2:datenZurAnfrage>
            <ns2:name>
              <ns2:nachname><name>#{entered_last_name}</name></ns2:nachname>
              <ns2:vornamen><name>Maria</name></ns2:vornamen>
            </ns2:name>
            <ns2:anschrift>
              <hausnummer>#{entered_number}</hausnummer>
              #{"<hausnummerBuchstabeZusatzziffer>#{entered_suffix}</hausnummerBuchstabeZusatzziffer>" if entered_suffix}
              <postleitzahl>45879</postleitzahl>
              <strasse>#{entered_street}</strasse>
              <wohnort>Gelsenkirchen</wohnort>
            </ns2:anschrift>
          </ns2:datenZurAnfrage>
          <ns2:ergebnis>
            <ns2:ergebnis>
              <ns2:namen>
                #{registered_names(version, last_name: registered_last_name, particle: registered_particle)}
              </ns2:namen>
              <ns2:anschrift.aktuell>
                <ns2:anschrift.inland>
                  <hausnummer>#{registered_number}</hausnummer>
                  #{"<hausnummerBuchstabeZusatzziffer>#{registered_suffix}</hausnummerBuchstabeZusatzziffer>" if registered_suffix}
                  <postleitzahl>45879</postleitzahl>
                  <strasse>#{registered_street}</strasse>
                  <wohnort>Gelsenkirchen</wohnort>
                </ns2:anschrift.inland>
              </ns2:anschrift.aktuell>
            </ns2:ergebnis>
          </ns2:ergebnis>
        </root>
      XML
    end

    def response(version: "3.4", street_check: false, entered_number: "12", entered_suffix: nil,
                 registered_number: "12", registered_suffix: nil, entered_last_name: "Muster",
                 registered_last_name: "Muster", registered_particle: nil,
                 entered_street: "Hauptstraße", registered_street: "Hauptstraße")
      body = registry_answer(version: version,
                             entered_number: entered_number,
                             entered_suffix: entered_suffix,
                             registered_number: registered_number,
                             registered_suffix: registered_suffix,
                             entered_last_name: entered_last_name,
                             registered_last_name: registered_last_name,
                             registered_particle: registered_particle,
                             entered_street: entered_street,
                             registered_street: registered_street)

      RemoteCensusApi::Response.new(Nokogiri::XML(body),
                                    version: RemoteCensusApi::XmeldVersion.new(version),
                                    street_check: street_check)
    end

    describe "the house number suffix" do
      it "rejects a suffix that differs from the registry entry" do
        expect(response(entered_suffix: "b", registered_suffix: "a")).not_to be_valid
      end

      it "rejects a missing suffix when the registry has one" do
        expect(response(entered_suffix: nil, registered_suffix: "a")).not_to be_valid
      end

      it "rejects a suffix the registry entry does not have" do
        expect(response(entered_suffix: "b", registered_suffix: nil)).not_to be_valid
      end

      it "accepts the same suffix regardless of case" do
        expect(response(entered_suffix: "A", registered_suffix: "a")).to be_valid
      end

      it "accepts a matching suffix" do
        expect(response(entered_suffix: "a", registered_suffix: "a")).to be_valid
      end

      it "accepts no suffix on either side" do
        expect(response(entered_suffix: nil, registered_suffix: nil)).to be_valid
      end

      it "is checked in the namespace of the configured version" do
        expect(response(version: "24.11", entered_suffix: "b", registered_suffix: "a")).not_to be_valid
      end
    end

    it "rejects a different house number, so the answer above is really being read" do
      expect(response(entered_number: "12", registered_number: "14")).not_to be_valid
    end

    describe "structured names (up to XMeld 25.05)" do
      it "joins the name particle with the last name" do
        expect(response(version: "24.11", entered_last_name: "von Muster",
                        registered_last_name: "Muster", registered_particle: "von")).to be_valid
      end

      it "rejects a different last name" do
        expect(response(version: "24.11", entered_last_name: "Mustermann")).not_to be_valid
      end
    end

    describe "unstructured names (XMeld 26.05 and later)" do
      it "accepts matching names" do
        expect(response(version: "26.11")).to be_valid
      end

      it "compares the full last name, particle included, regardless of case" do
        expect(response(version: "26.11", entered_last_name: "von muster",
                        registered_last_name: "von Muster")).to be_valid
      end

      it "rejects a different last name" do
        expect(response(version: "26.11", entered_last_name: "Mustermann")).not_to be_valid
      end
    end

    it "does not count names missing on both sides as a match" do
      body = Nokogiri::XML(<<~XML)
        <root xmlns:ns2="http://www.osci.de/xmeld2605">
          <ns2:ergebnis><ns2:ergebnis><ns2:ergebnisstatus><code>05</code></ns2:ergebnisstatus></ns2:ergebnis></ns2:ergebnis>
        </root>
      XML
      response = RemoteCensusApi::Response.new(body, version: RemoteCensusApi::XmeldVersion.new("26.05"))

      expect(response.first_name_matched?).to be false
      expect(response.last_name_matched?).to be false
    end

    describe "the street check" do
      it "ignores the street when it is off" do
        expect(response(registered_street: "Nebenstraße")).to be_valid
      end

      it "rejects a different street when it is on" do
        expect(response(street_check: true, registered_street: "Nebenstraße")).not_to be_valid
      end

      it "accepts the same street when it is on" do
        expect(response(street_check: true)).to be_valid
      end

      it "accepts the spellings the register itself treats as the same street" do
        {
          "Frankfurter Str." => "Frankfurter Straße",
          "frankfurter str" => "Frankfurter Straße",
          "Frankfurter  Strasse" => "Frankfurter Straße",
          "Hauptstr." => "Hauptstraße",
          "Marktpl." => "Marktplatz",
          "Am Pl" => "Am Platz"
        }.each do |entered, registered|
          expect(response(street_check: true, entered_street: entered, registered_street: registered))
            .to be_valid, "expected #{entered.inspect} to match #{registered.inspect}"
        end
      end

      it "rejects a street without its street type" do
        expect(response(street_check: true, entered_street: "Frankfurter",
                        registered_street: "Frankfurter Straße")).not_to be_valid
      end
    end
  end

  describe RemoteCensusApi::XmeldVersion do
    it "rejects a version it has no message format for" do
      expect { RemoteCensusApi::XmeldVersion.new("27.05") }.to raise_error(ArgumentError, /27\.05/)
    end
  end

  describe "#call" do
    let(:http) { instance_double(Net::HTTP, :use_ssl= => true) }
    let(:sent_requests) { [] }
    let(:settings) do
      {
        endpoint: "https://register.example.org/XWS/ws/XMeld2611Service",
        username: "user",
        password: "secret",
        version: "26.11",
        behoerdenkennung: "ags:05382060",
        organisationseinheit: "Siegburg"
      }
    end

    before do
      allow(Rails.application.secrets).to receive(:xmeld).and_return(settings)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:request) do |request|
        sent_requests << request
        instance_double(Net::HTTPResponse, read_body: "<root/>")
      end
    end

    def call_api(gender: "female")
      RemoteCensusApi.new.call(first_name: "Maria", last_name: "Muster", street_name: "Hauptstraße",
                               street_number: "12", street_number_extension: "", plz: "53721",
                               city_name: "Siegburg", date_of_birth: "1980-05-17", gender: gender)
    end

    def sent_node(path, namespace_token = "2611")
      Nokogiri::XML(sent_requests.last.body).at_xpath(path, "x" => "http://www.osci.de/xmeld#{namespace_token}")
    end

    it "posts to the configured endpoint with the configured credentials and no proxy" do
      call_api

      expect(Net::HTTP).to have_received(:new).with("register.example.org", 443)
      expect(sent_requests.last.path).to eq "/XWS/ws/XMeld2611Service"
      expect(sent_requests.last["X-username"]).to eq "user"
      expect(sent_requests.last["X-password"]).to eq "secret"
    end

    it "goes through the proxy when one is configured" do
      settings.merge!(proxy_ip: "10.0.0.1", proxy_port: 3128)

      call_api

      expect(Net::HTTP).to have_received(:new).with("register.example.org", 443, "10.0.0.1", 3128)
    end

    it "addresses the configured authority in the configured version" do
      call_api

      message = sent_node("//x:melderegisterauskunfteinfach.anforderung.0600")
      expect(message["version"]).to eq "26.11"
      expect(message["fassung"]).to eq "2026-01-31"
      expect(sent_node("//x:empfaenger/x:behoerdenkennung").text).to eq "ags:05382060"
      expect(sent_node("//x:empfaenger//x:bezeichnung").text).to eq "Siegburg"
    end

    it "sends the gender with the code list the schema fixes" do
      call_api

      expect(sent_node("//x:geschlecht")["listURI"]).to eq "urn:xoev-de:xinneres:codeliste:geschlecht"
      expect(sent_node("//x:geschlecht")["listVersionID"]).to eq "1"
    end

    it "maps each gender option to its code in the XInneres code list" do
      { "male" => "m", "female" => "w", "other_gen" => "d" }.each do |gender, code|
        call_api(gender: gender)

        expect(sent_node("//x:geschlecht/code").text).to eq code
      end
    end

    it "leaves the gender out when the user has none, so the register does not filter by it" do
      call_api(gender: nil)

      expect(sent_node("//x:geschlechtOderFamilienstand")).to be_nil
    end

    it "sends the sender name unstructured from XMeld 26.05 on" do
      call_api

      expect(sent_node("//x:NAMENATUERLICHEPERSON/x:familienname.unstrukturiert/x:nachname/name"))
        .to be_present
      expect(sent_node("//x:NAMENATUERLICHEPERSON/x:vornamen/x:vornamen/name")).to be_present
    end

    it "sends the sender name structured up to XMeld 25.05" do
      settings[:version] = "24.11"

      call_api

      expect(sent_node("//x:NAMENATUERLICHEPERSON/x:familienname/x:nachname", "2411")).to be_present
      expect(sent_node("//x:NAMENATUERLICHEPERSON/x:vornamen/name", "2411")).to be_present
    end
  end
end
