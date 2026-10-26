class RemoteCensusApi
  require "uri"
  require "net/http"

  GENDER_CODES = { "male" => "m", "female" => "w", "other_gen" => "d" }.freeze

  def call(first_name:, last_name:, street_name:, street_number:, street_number_extension:, plz:, city_name:, date_of_birth:, gender:)
    gender = GENDER_CODES[gender]

    Response.new(get_response_body(first_name: first_name,
                                   last_name: last_name,
                                   street_name: street_name,
                                   street_number: street_number,
                                   street_number_extension: street_number_extension,
                                   plz: plz,
                                   city_name: city_name,
                                   date_of_birth: date_of_birth,
                                   gender: gender),
                 version: version,
                 street_check: settings[:street_check] == true)
  end

  class XmeldVersion
    VERSIONS = {
      "3.4" => { namespace_token: "34", fassung: "2024-01-31", unstructured_names: false },
      "24.11" => { namespace_token: "2411", fassung: "2024-01-31", unstructured_names: false },
      "25.05" => { namespace_token: "2505", fassung: "2024-07-31", unstructured_names: false },
      "26.05" => { namespace_token: "2605", fassung: "2025-07-31", unstructured_names: true },
      "26.11" => { namespace_token: "2611", fassung: "2026-01-31", unstructured_names: true }
    }.freeze

    attr_reader :number

    def initialize(number)
      @number = number.to_s
      @attributes = VERSIONS.fetch(@number) do
        raise ArgumentError, "Unsupported XMeld version #{number.inspect}, expected one of #{VERSIONS.keys.join(", ")}"
      end
    end

    def namespace
      "http://www.osci.de/xmeld#{@attributes[:namespace_token]}"
    end

    def service_namespace
      "XMeld#{@attributes[:namespace_token]}Auskunft"
    end

    def fassung
      @attributes[:fassung]
    end

    def unstructured_names?
      @attributes[:unstructured_names]
    end
  end

  class Response
    def initialize(body, version:, street_check: false)
      @body = body
      @version = version
      @street_check = street_check
    end

    def valid?
      response_code_matched? &&
        first_name_matched? &&
        last_name_matched? &&
        house_number_matched? &&
        house_number_extension_matched? &&
        postleitzahl_matched? &&
        (!@street_check || street_matched?) &&
        city_matched?
    end

    def response_code_matched?
      xpath("//ns2:ergebnisstatus/code").text == "01"
    end

    def first_name_matched?
      registered_first_name = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:vornamen/name").text

      registered_first_name.present? &&
        registered_first_name == xpath("//ns2:datenZurAnfrage //ns2:vornamen/name").text
    end

    def last_name_matched?
      registered = registered_last_name.strip.downcase

      registered.present? && registered == xpath("//ns2:datenZurAnfrage //ns2:nachname/name").text.downcase
    end

    def house_number_matched?
      request_house_number = xpath("//ns2:datenZurAnfrage //ns2:anschrift/hausnummer").text
      registered_house_numbers = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //hausnummer").map(&:text)

      request_house_number.in?(registered_house_numbers)
    end

    def house_number_extension_matched?
      request_house_number_extension = xpath("//ns2:datenZurAnfrage //ns2:anschrift/hausnummerBuchstabeZusatzziffer").text
      registered_house_number_extensions = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //hausnummerBuchstabeZusatzziffer").map(&:text)

      return true if request_house_number_extension.blank? && registered_house_number_extensions.blank?

      request_house_number_extension.downcase.in?(registered_house_number_extensions.map(&:downcase))
    end

    def postleitzahl_matched?
      request_plz = xpath("//ns2:datenZurAnfrage //ns2:anschrift/postleitzahl").text
      registered_plzs = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //postleitzahl").map(&:text)

      request_plz.in?(registered_plzs)
    end

    def street_matched?
      request_street = normalized_street(xpath("//ns2:datenZurAnfrage //ns2:anschrift/strasse").text)
      registered_streets = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //strasse")
                             .map { |street| normalized_street(street.text) }

      request_street.present? && request_street.in?(registered_streets)
    end

    def city_matched?
      request_city = xpath("//ns2:datenZurAnfrage //ns2:anschrift/wohnort").text
      registered_cities = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:anschrift.aktuell //wohnort").map(&:text)

      request_city.in?(registered_cities)
    end

    private

      def xpath(path)
        @body.xpath(path, "ns2" => @version.namespace)
      end

      def registered_last_name
        if @version.unstructured_names?
          xpath("//ns2:ergebnis/ns2:ergebnis //ns2:familienname.unstrukturiert/ns2:nachname/name").text
        else
          last_name_particle = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:familienname/ns2:namensbestandteil").text
          last_name = xpath("//ns2:ergebnis/ns2:ergebnis //ns2:familienname/ns2:nachname").text

          [last_name_particle, last_name].join(" ")
        end
      end

      def normalized_street(street)
        street.downcase.gsub("ß", "ss")
              .gsub(/strasse\b/, "str").gsub("str.", "str")
              .gsub(/platz\b/, "pl").gsub("pl.", "pl")
              .squish
      end
  end

  private

    def settings
      @settings ||= Rails.application.secrets.xmeld || {}
    end

    def version
      @version ||= XmeldVersion.new(settings[:version])
    end

    def proxy
      settings[:proxy_ip].present? ? [settings[:proxy_ip], settings[:proxy_port]] : []
    end

    def get_response_body(first_name:, last_name:, street_name:, street_number:, street_number_extension:, plz:, city_name:, date_of_birth:, gender:)
      url = URI(settings[:endpoint])
      https = Net::HTTP.new(url.host, url.port, *proxy)
      https.use_ssl = true

      request = Net::HTTP::Post.new(url)
      request["X-username"] = settings[:username]
      request["X-password"] = settings[:password]
      request["Content-Type"] = "text/xml"

      request.body = form_request_xml(first_name: first_name,
                                      last_name: last_name,
                                      street_name: street_name,
                                      street_number: street_number,
                                      street_number_extension: street_number_extension,
                                      plz: plz,
                                      city_name: city_name,
                                      date_of_birth: date_of_birth,
                                      gender: gender)

      response = https.request(request)
      Nokogiri::XML(response.read_body)
    end

    def form_request_xml(first_name:, last_name:, street_name:, street_number:, street_number_extension:, plz:, city_name:, date_of_birth:, gender:)
      xmeld_version = version
      behoerdenkennung = settings[:behoerdenkennung]
      organisationseinheit = settings[:organisationseinheit]
      b = Nokogiri::XML::Builder.new(encoding: "UTF-8")

      b.Envelope("xmlns:xmel": xmeld_version.service_namespace, "xmlns:xmel1": xmeld_version.namespace) {
        b.parent.namespace = b.parent.add_namespace_definition("soapenv", "http://schemas.xmlsoap.org/soap/envelope/")
        b["soapenv"].Header
        b["soapenv"].Body {
          b["xmel"].abfrage0600 {
            b["xmel1"].send("melderegisterauskunfteinfach.anforderung.0600", fassung: xmeld_version.fassung, id: "ID_1", produkt: "?", produkthersteller: "?", produktversion: "?", test: "?", version: xmeld_version.number ) {
              b.nachrichtenkopf {
                b.send("identifikation.nachricht") {
                  b.nachrichtennummer(listURI: "urn:de:xmeld:schluesseltabelle:xmeld.nachrichten", listVersionID: xmeld_version.number) {
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
                      if xmeld_version.unstructured_names?
                        b.send("familienname.unstrukturiert") {
                          b.nachname {
                            b.name {
                              b.parent.content = "Mustermann 1"
                              b.parent.namespace = nil
                            }
                          }
                        }
                        b.vornamen {
                          b.vornamen {
                            b.name {
                              b.parent.content = "xMaximilian "
                              b.parent.namespace = nil
                            }
                          }
                        }
                      else
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
                      end
                    }
                  }
                }
                b.empfaenger {
                  b.behoerdenkennung(behoerdenkennung)
                  b.ORGANISATIONSEINHEIT {
                    b.bezeichnung(organisationseinheit)
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
                    b.hausnummerBuchstabeZusatzziffer {
                      b.parent.content = street_number_extension
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
                  if gender
                    b.geschlechtOderFamilienstand {
                      b.geschlecht(listURI: "urn:xoev-de:xinneres:codeliste:geschlecht", listVersionID: 1) {
                        b.code {
                          b.parent.content = gender
                          b.parent.namespace = nil
                        }
                      }
                    }
                  end
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
