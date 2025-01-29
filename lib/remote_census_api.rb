class RemoteCensusApi
  require "uri"
  require "net/http"

  def call(first_name:, last_name:, street_name:, street_number:, plz:, city_name:, date_of_birth:, gender:)
    gender = gender == "male" ? "m" : "w"

    Response.new(get_response_body(first_name: first_name,
                                   last_name: last_name,
                                   street_name: street_name,
                                   street_number: street_number,
                                   plz: plz,
                                   city_name: city_name,
                                   date_of_birth: date_of_birth,
                                   gender: gender))
  end

  class Response
    def initialize(body)
      @body = body
    end

    def valid?
      response_code_matched? &&
        first_name_matched? &&
        last_name_matched? &&
        house_number_matched? &&
        postleitzahl_matched? &&
        city_matched?
    end

    def response_code_matched?
      @body.xpath("//ns2:ergebnisstatus/code", "ns2" => "http://www.osci.de/xmeld34").text == "01"
    end

    def first_name_matched?
      @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:vornamen/name", "ns2" => "http://www.osci.de/xmeld34").text ==
        @body.xpath("//ns2:datenZurAnfrage //ns2:vornamen/name", "ns2" => "http://www.osci.de/xmeld34").text
    end

    def last_name_matched?
      last_name_particle = @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:familienname/ns2:namensbestandteil", "ns2" => "http://www.osci.de/xmeld34").text
      last_name = @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:familienname/ns2:nachname", "ns2" => "http://www.osci.de/xmeld34").text

      [last_name_particle, last_name].join(" ").strip.downcase ==
        @body.xpath("//ns2:datenZurAnfrage //ns2:nachname/name", "ns2" => "http://www.osci.de/xmeld34").text.downcase
    end

    def house_number_matched?
      request_house_number = @body.xpath("//ns2:datenZurAnfrage //ns2:anschrift/hausnummer", "ns2" => "http://www.osci.de/xmeld34").text
      registered_house_numbers = @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //hausnummer", "ns2" => "http://www.osci.de/xmeld34").map(&:text)

      request_house_number.in?(registered_house_numbers)
    end

    def postleitzahl_matched?
      request_plz = @body.xpath("//ns2:datenZurAnfrage //ns2:anschrift/postleitzahl", "ns2" => "http://www.osci.de/xmeld34").text
      registered_plzs = @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //postleitzahl", "ns2" => "http://www.osci.de/xmeld34").map(&:text)

      request_plz.in?(registered_plzs)
    end

    def street_matched?
      request_street = @body.xpath("//ns2:datenZurAnfrage //ns2:anschrift/strasse", "ns2" => "http://www.osci.de/xmeld34").text
      registered_streets = @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //strasse", "ns2" => "http://www.osci.de/xmeld34").map(&:text)

      request_street.in?(registered_streets)
    end

    def city_matched?
      request_city = @body.xpath("//ns2:datenZurAnfrage //ns2:anschrift/wohnort", "ns2" => "http://www.osci.de/xmeld34").text
      registered_cities = @body.xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //wohnort", "ns2" => "http://www.osci.de/xmeld34").map(&:text)

      request_city.in?(registered_cities)
    end
  end

  private

    def get_response_body(first_name:, last_name:, street_name:, street_number:, plz:, city_name:, date_of_birth:, gender:)
      url = URI(Rails.application.secrets.soap_endpoint)
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(url)
      request["X-username"] = Rails.application.secrets.soap_username
      request["X-password"] = Rails.application.secrets.soap_password
      request["Content-Type"] = "text/xml"

      request.body = form_request_xml(first_name: first_name,
                                      last_name: last_name,
                                      street_name: street_name,
                                      street_number: street_number,
                                      plz: plz,
                                      city_name: city_name,
                                      date_of_birth: date_of_birth,
                                      gender: gender)

      response = https.request(request)
      Nokogiri::XML(response.read_body)
    end

    def form_request_xml(first_name:, last_name:, street_name:, street_number:, plz:, city_name:, date_of_birth:, gender:)
      b = Nokogiri::XML::Builder.new(encoding: "UTF-8")

      b.Envelope("xmlns:xmel": "XMeld34Auskunft", "xmlns:xmel1": "http://www.osci.de/xmeld34") {
        b.parent.namespace = b.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
        b["soapenv"].Header
        b["soapenv"].Body {
          b["xmel"].abfrage0600 {
            b["xmel1"].send("melderegisterauskunfteinfach.anforderung.0600", fassung: "2024-01-31", id: "ID_1", produkt: "?", produkthersteller: "?", produktversion: "?", test: "?", version: "3.4" ) {
              b.nachrichtenkopf {
                b.send("identifikation.nachricht") {
                  b.nachrichtennummer(listURI: "urn:de:xmeld:schluesseltabelle:xmeld.nachrichten", listVersionID: "3.4") {
                    b.code {
                      b.parent.content = "0600"
                      b.parent.namespace = nil
                    }
                  }
                  b.erstellungszeitpunkt(Time.current.strftime("%Y-%m-%dT%H:%M:%S"))
                  b.tagesvorgangszaehler(1)
                }
                b.anwenderkennung("privat")
                b.absender {
                  b.send("kunde.bezeichnung") {
                    b.NAMENATUERLICHEPERSON {
                      b.familienname {
                        b.nachname{
                          b.parent.content = "Mustermann 1"
                        }
                      }
                      b.vornamen {
                        b.name {
                          b.parent.content = "xMaximilian "
                          b.parent.namespace = nil
                        }
                      }
                    }
                  }
                }
                b.empfaenger {
                  b.behoerdenkennung("ags:05513000")
                  b.ORGANISATIONSEINHEIT {
                    b.bezeichnung("Gelsenkirchen")
                    b.hierarchieebene(1)
                  }
                }
              }
              b.zeichennachricht("zeichennachricht")
              b.anwenderkennung("privat")
              b.send("auskunft.anforderung") {
                b.anfragedaten {
                  b.gewerblicherZweck {
                    b.angabeDesZwecks {
                      b.code(listURI: "urn:de:xmeld:schluesseltabelle:melderegisterauskunft.gewerblicher.zweck", listVersionID: "?") {
                        b.code {
                          b.parent.content = 4
                          b.parent.namespace = nil
                        }
                      }
                      b.freitext("Auftraggeber: TESTER")
                    }
                    b.geschaeftszeichen("Test")
                  }
                  b.zeicheneinzelfall("programmtest")
                  b.zumZweckDerWerbungOderAdresshandel("false")
                }
                b.datenZurAnfrage {
                  b.name {
                    b.nachname {
                      b.name {
                        b.parent.content = last_name
                        b.parent.namespace = nil
                      }
                    }
                    b.vornamen {
                      b.name {
                        b.parent.content = first_name
                        b.parent.namespace = nil
                      }
                    }
                    b.phonetik(true)
                  }
                  b.anschrift {
                    b.hausnummer {
                      b.parent.content = street_number
                      b.parent.namespace = nil
                    }
                    b.postleitzahl {
                      b.parent.content = plz
                      b.parent.namespace = nil
                    }
                    b.strasse {
                      b.parent.content = street_name
                      b.parent.namespace = nil
                    }
                    b.wohnort {
                      b.parent.content = city_name
                      b.parent.namespace = nil
                    }
                  }
                  b.geburtsdatum {
                    b.teilbekanntesDatum {
                      b.parent.namespace = nil
                      b.jahrMonatTag {
                        b.parent.content = date_of_birth
                        b.parent.namespace = nil
                      }
                    }
                  }
                  b.geschlechtOderFamilienstand {
                    b.geschlecht(listURI: "urn:de:dsmeld:schluesseltabelle:geschlecht", listVersionID: 2) {
                      b.code {
                        b.parent.content = gender
                        b.parent.namespace = nil
                      }
                    }
                  }
                }
                b.steuerungsinformationen {
                  b.send("option.auskunft", listURI: "urn:de:xmeld:schluesseltabelle:melderegisterauskunft.optionen", listVersionID: 2) {
                    b.code {
                      b.parent.content = "01"
                      b.parent.namespace = nil
                    }
                  }
                }
                b.send("technische.einzelidentifikation") {
                  b.ereigniszeitpunkt(Time.current.strftime("%Y-%m-%dT%H:%M:%S"))
                  b.zeicheneinzelfall("TESTANFRAGE")
                }
              }
            }
          }
        }
      }

      Nokogiri::XML(b.to_xml).root.to_xml.to_s
    end
end
