require "rails_helper"

describe RemoteCensusApi do
  describe RemoteCensusApi::Response do
    def registry_answer(entered_number:, entered_suffix:, registered_number:, registered_suffix:)
      <<~XML
        <root xmlns:ns2="http://www.osci.de/xmeld34">
          <ns2:ergebnisstatus><code>01</code></ns2:ergebnisstatus>
          <ns2:datenZurAnfrage>
            <ns2:person>
              <ns2:nachname><name>Muster</name></ns2:nachname>
              <ns2:vornamen><name>Maria</name></ns2:vornamen>
              <ns2:anschrift>
                <hausnummer>#{entered_number}</hausnummer>
                #{"<hausnummerBuchstabeZusatzziffer>#{entered_suffix}</hausnummerBuchstabeZusatzziffer>" if entered_suffix}
                <postleitzahl>45879</postleitzahl>
                <wohnort>Gelsenkirchen</wohnort>
              </ns2:anschrift>
            </ns2:person>
          </ns2:datenZurAnfrage>
          <ns2:ergebnis>
            <ns2:ergebnis>
              <ns2:familienname><ns2:nachname>Muster</ns2:nachname></ns2:familienname>
              <ns2:vornamen><name>Maria</name></ns2:vornamen>
              <ns2:anschrift.aktuell>
                <anschrift>
                  <hausnummer>#{registered_number}</hausnummer>
                  #{"<hausnummerBuchstabeZusatzziffer>#{registered_suffix}</hausnummerBuchstabeZusatzziffer>" if registered_suffix}
                  <postleitzahl>45879</postleitzahl>
                  <wohnort>Gelsenkirchen</wohnort>
                </anschrift>
              </ns2:anschrift.aktuell>
            </ns2:ergebnis>
          </ns2:ergebnis>
        </root>
      XML
    end

    def response(entered_number: "12", entered_suffix: nil, registered_number: "12", registered_suffix: nil)
      RemoteCensusApi::Response.new(Nokogiri::XML(registry_answer(entered_number: entered_number,
                                                                  entered_suffix: entered_suffix,
                                                                  registered_number: registered_number,
                                                                  registered_suffix: registered_suffix)))
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
    end

    it "rejects a different house number, so the answer above is really being read" do
      expect(response(entered_number: "12", registered_number: "14")).not_to be_valid
    end
  end
end
