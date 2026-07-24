def privacy_page_content
  <<~'HTML'
  <h1>Datenschutzerklärung</h1>

  <h2>1. Allgemeine Hinweise</h2>

  <p>Der Schutz Ihrer persönlichen Daten ist uns ein besonderes Anliegen. Wir verarbeiten Ihre Daten daher ausschließlich auf Grundlage der gesetzlichen Bestimmungen, insbesondere der Europäischen Datenschutz-Grundverordnung (DSGVO) und des {{LDSG_NAME}}.</p>

  <p>Diese Datenschutzerklärung informiert Sie gemäß Art. 12, 13 und 14 DSGVO über die Art, den Umfang und die Zwecke der Erhebung und Verwendung personenbezogener Daten auf der Beteiligungsplattform <strong>{{PLATTFORM_NAME}}</strong> unter <strong>{{PLATTFORM_URL}}</strong> (nachfolgend „Plattform&quot;).</p>

  <p>Personenbezogene Daten sind alle Informationen, die sich auf eine identifizierte oder identifizierbare natürliche Person beziehen (Art. 4 Nr. 1 DSGVO).</p>

  <hr>

  <h2>2. Verantwortlicher</h2>

  <p>Verantwortlich für die Datenverarbeitung im Sinne der DSGVO ist:</p>

  <p><strong>{{STADT_NAME}}</strong>
  {{STADT_ADRESSE}}
  Telefon: {{STADT_TELEFON}}
  E-Mail: {{STADT_EMAIL}}
  Website: {{STADT_WEBSITE}}</p>

  <hr>

  <h2>3. Datenschutzbeauftragte/r</h2>

  <p>Bei Fragen zum Datenschutz erreichen Sie unsere/n behördliche/n Datenschutzbeauftragte/n unter:</p>

  <p>{{DSB_NAME}}
  {{DSB_ADRESSE}}
  Telefon: {{DSB_TELEFON}}
  E-Mail: {{DSB_EMAIL}}</p>

  <hr>

  <h2>4. Auftragsverarbeiter</h2>

  <p>Die technische Bereitstellung und Wartung der Plattform erfolgt durch:</p>

  <p><strong>demokratie.today</strong>
  Mühlleite 13
  91465 Ergersheim
  E-Mail: <a href="mailto:info@demokratie.today">info@demokratie.today</a>
  Website: demokratie.today</p>

  <p>demokratie.today verarbeitet Ihre Daten ausschließlich im Auftrag und nach Weisung des Verantwortlichen gemäß Art. 28 DSGVO. Grundlage ist ein Auftragsverarbeitungsvertrag (AVV), der die Einhaltung der datenschutzrechtlichen Anforderungen sicherstellt.</p>

  <p>Das Hosting der Plattform erfolgt auf Servern der <strong>{{HOSTING_PROVIDER}}</strong> in Deutschland.</p>

  <hr>

  <h2>5. Zwecke und Rechtsgrundlagen der Datenverarbeitung</h2>

  <h3>5.1 Server-Logdaten</h3>

  <p>Bei jedem Zugriff auf die Plattform werden automatisch folgende Daten erfasst und in Server-Logdateien gespeichert:</p>

  <ul>
  <li>IP-Adresse des anfragenden Rechners</li>
  <li>Datum und Uhrzeit des Zugriffs</li>
  <li>Name und URL der abgerufenen Seite</li>
  <li>Übertragene Datenmenge</li>
  <li>Browsertyp und -version</li>
  <li>Verwendetes Betriebssystem</li>
  <li>Referrer-URL (zuvor besuchte Seite)</li>
  </ul>

  <p><strong>Rechtsgrundlage:</strong> Art. 6 Abs. 1 lit. e DSGVO i.V.m. {{LDSG_REFERENZ}} (Wahrnehmung einer Aufgabe im öffentlichen Interesse). Die Verarbeitung ist aus Gründen der technischen Sicherheit, insbesondere zur Abwehr von Angriffsversuchen auf den Webserver, erforderlich.</p>

  <p><strong>Speicherdauer:</strong> Die IP-Adressen werden nach spätestens 7 Tagen gelöscht. Die übrigen Logdaten werden in anonymisierter Form für statistische Zwecke aufbewahrt.</p>

  <hr>

  <h3>5.2 SSL-/TLS-Verschlüsselung</h3>

  <p>Die Plattform nutzt aus Sicherheitsgründen und zum Schutz der Übertragung personenbezogener Daten eine SSL- bzw. TLS-Verschlüsselung. Eine verschlüsselte Verbindung erkennen Sie daran, dass die Adresszeile des Browsers von „http://&quot; auf „https://&quot; wechselt und an dem Schloss-Symbol in Ihrer Browserzeile.</p>

  <hr>

  <h3>5.3 Cookies</h3>

  <p>Die Plattform verwendet Cookies. Cookies sind kleine Textdateien, die auf Ihrem Endgerät gespeichert werden und die Ihr Browser beim nächsten Besuch wieder an die Plattform sendet.</p>

  <h4>Technisch notwendige Cookies</h4>

  <p>Die Plattform setzt technisch notwendige Cookies ein, die für den Betrieb der Plattform zwingend erforderlich sind:</p>

  <ul>
  <li><strong>Session-Cookie:</strong> Ermöglicht die Zuordnung Ihrer Anfragen zu Ihrer Sitzung. Wird nach Beenden der Browsersitzung gelöscht.</li>
  <li><strong>CSRF-Token:</strong> Schützt vor Cross-Site-Request-Forgery-Angriffen.</li>
  <li><strong>Cookie-Einstellungen:</strong> Speichert Ihre Cookie-Präferenzen.</li>
  </ul>

  <p><strong>Rechtsgrundlage:</strong> § 25 Abs. 2 TDDDG sowie Art. 6 Abs. 1 lit. e DSGVO i.V.m. {{LDSG_REFERENZ}}. Diese Cookies sind für den Betrieb der Plattform technisch erforderlich.</p>

  <h4>Analyse-Cookies (nur mit Einwilligung)</h4>

  <!-- MODULE:matomo-cookies -->

  <!-- MODULE:matomo-cookieless -->

  <p>Sie können Ihren Browser so einstellen, dass Sie über das Setzen von Cookies informiert werden und Cookies nur im Einzelfall erlauben, die Annahme von Cookies für bestimmte Fälle oder generell ausschließen sowie das automatische Löschen der Cookies beim Schließen des Browsers aktivieren. Bei der Deaktivierung von Cookies kann die Funktionalität der Plattform eingeschränkt sein.</p>

  <hr>

  <h3>5.4 Registrierung und Nutzerkonto</h3>

  <p>Für die aktive Teilnahme an Beteiligungsverfahren ist eine Registrierung auf der Plattform erforderlich. Bei der Registrierung werden folgende Daten erhoben:</p>

  <ul>
  <li>Benutzername (frei wählbar)</li>
  <li>E-Mail-Adresse</li>
  <li>Passwort (wird verschlüsselt gespeichert)</li>
  </ul>

  <p>Optional können Sie weitere Angaben machen, insbesondere wenn für bestimmte Beteiligungsverfahren eine Verifikation oder ein Wohnsitznachweis erforderlich ist:</p>

  <ul>
  <li>Vor- und Nachname</li>
  <li>Postleitzahl / Adresse</li>
  <li>Geburtsdatum</li>
  <li>Geschlecht</li>
  </ul>

  <p><strong>Rechtsgrundlage:</strong> Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung) für die Registrierung. Art. 6 Abs. 1 lit. a DSGVO (Einwilligung) für optionale Angaben.</p>

  <p><strong>Öffentlich sichtbar</strong> sind auf der Plattform: Ihr Benutzername, die Anzahl Ihrer Aktivitäten sowie Ihre Beiträge (Vorschläge, Kommentare, Abstimmungsteilnahmen). Alle weiteren Daten sind nicht öffentlich einsehbar.</p>

  <p><strong>Speicherdauer:</strong> Ihre Kontodaten werden gespeichert, solange Ihr Nutzerkonto besteht. Bei Löschung Ihres Kontos werden Ihre personenbezogenen Daten gelöscht. Öffentliche Beiträge (Vorschläge, Kommentare) werden anonymisiert und bleiben ohne Personenbezug erhalten.</p>

  <h4>Registrierung über Drittanbieter (Social Login)</h4>

  <!-- MODULE:facebook -->

  <!-- MODULE:google -->

  <!-- MODULE:x-twitter -->

  <!-- MODULE:wordpress -->

  <hr>

  <h3>5.5 Identitätsprüfung / Verifizierung</h3>

  <p>Für bestimmte Beteiligungsverfahren kann eine Identitätsprüfung oder ein Wohnsitznachweis erforderlich sein, um sicherzustellen, dass nur berechtigte Personen teilnehmen. Je nach Konfiguration des Beteiligungsverfahrens stehen folgende Verifizierungsmethoden zur Verfügung:</p>

  <!-- MODULE:bundid -->

  <!-- MODULE:bayernid -->

  <!-- MODULE:servicekonto-nrw -->

  <!-- MODULE:openrathaus -->

  <!-- MODULE:sms -->

  <!-- MODULE:letter -->

  <!-- MODULE:melderegister -->

  <p><strong>Rechtsgrundlage:</strong> Art. 6 Abs. 1 lit. a DSGVO (Einwilligung) oder Art. 6 Abs. 1 lit. e DSGVO (Wahrnehmung einer Aufgabe im öffentlichen Interesse), je nach Ausgestaltung des Beteiligungsverfahrens.</p>

  <p><strong>Speicherdauer:</strong> Verifizierungsdaten werden gespeichert, solange Ihr Nutzerkonto besteht, und bei Kontolöschung gelöscht.</p>

  <hr>

  <h3>5.6 Bürgerbeteiligung</h3>

  <p>Im Rahmen der Nutzung der Plattform können Sie an verschiedenen Beteiligungsverfahren teilnehmen. Je nach Art des Beteiligungsverfahrens können dabei folgende Daten verarbeitet werden:</p>

  <ul>
  <li><strong>Textbeiträge:</strong> Vorschläge, Ideen, Kommentare, Diskussionsbeiträge, Mängelmeldungen – jeweils mit Titel, Beschreibungstext und Zeitstempel</li>
  <li><strong>Bilder und Dokumente:</strong> Hochgeladene Fotos, Dokumente oder andere Dateien zu Ihren Beiträgen. Metadaten (z. B. EXIF-Daten in Fotos) werden beim Upload entfernt</li>
  <li><strong>Standortdaten:</strong> Kartenmarkierungen (Pins) und Geokoordinaten, die Sie Ihren Beiträgen zuordnen, ggf. mit Adressnäherung</li>
  <li><strong>Abstimmungen:</strong> Ihre Stimmabgabe (die konkrete Stimmabgabe ist nicht öffentlich einsehbar, die Teilnahme an einer Abstimmung kann jedoch sichtbar sein)</li>
  <li><strong>Umfragen:</strong> Ihre Antworten auf Umfragefragen</li>
  <li><strong>Formulareingaben:</strong> Alle von Ihnen in Formulare eingegebenen Daten (Textfelder, Auswahlen, Datumsangaben, Datei-Uploads). Ob Ihre Eingabe anonym oder mit Ihrem Benutzernamen verknüpft erfolgt, hängt von der Konfiguration des jeweiligen Verfahrens ab. Sie werden vor dem Absenden darüber informiert</li>
  <li><strong>Veranstaltungen:</strong> Anmeldungen zu Veranstaltungen im Rahmen von Beteiligungsverfahren. Ihre Anmeldung ist nur für die Verwaltung sichtbar und wird nicht öffentlich angezeigt</li>
  <li><strong>Bewertungen:</strong> Zustimmungen oder Ablehnungen zu Beiträgen anderer Nutzender</li>
  </ul>

  <p>Ihre Textbeiträge, Bilder und Standortmarkierungen werden in Verbindung mit Ihrem Benutzernamen auf der Plattform veröffentlicht. Bitte achten Sie darauf, keine Fotos hochzuladen, die Personen oder private Kennzeichen erkennbar zeigen.</p>

  <p><strong>Rechtsgrundlage:</strong> Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung) bzw. Art. 6 Abs. 1 lit. e DSGVO (Wahrnehmung einer Aufgabe im öffentlichen Interesse).</p>

  <p><strong>Speicherdauer:</strong> Formulardaten werden für die Dauer des Beteiligungsverfahrens und dessen Auswertung gespeichert. Veranstaltungsanmeldungen werden nach Durchführung gelöscht, sofern keine Dokumentationspflichten bestehen. Alle übrigen Beiträge werden bei Kontolöschung anonymisiert (siehe Abschnitt 8).</p>

  <hr>

  <h3>5.7 Kontakt und Support</h3>

  <p>Wenn Sie uns per E-Mail oder über ein Kontaktformular kontaktieren, werden Ihre Angaben (Name, E-Mail-Adresse, Nachrichteninhalt) zur Bearbeitung Ihrer Anfrage verarbeitet und gespeichert.</p>

  <p><strong>Rechtsgrundlage:</strong> Art. 6 Abs. 1 lit. a DSGVO (Einwilligung) oder Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung), sofern Ihre Anfrage mit der Nutzung der Plattform zusammenhängt.</p>

  <p><strong>Speicherdauer:</strong> Die Daten werden gelöscht, sobald Ihre Anfrage abschließend bearbeitet wurde und keine gesetzlichen Aufbewahrungspflichten entgegenstehen.</p>

  <hr>

  <h3>5.8 KI-gestützte Funktionen</h3>

  <!-- MODULE:ki-nutzerhilfe -->

  <!-- MODULE:ki-uebersetzung -->

  <hr>

  <h3>5.9 Externe Inhalte und Kartendienste</h3>

  <p>Die Plattform kann externe Inhalte einbinden (z. B. Videos, Karten, interaktive Inhalte). Um Ihre Privatsphäre zu schützen, werden externe Inhalte erst nach Ihrer ausdrücklichen Zustimmung geladen (<strong>Zwei-Klick-Lösung</strong>). Erst wenn Sie den externen Inhalt aktiv freischalten, wird eine Verbindung zum jeweiligen Drittanbieter hergestellt.</p>

  <p><strong>Rechtsgrundlage:</strong> Art. 6 Abs. 1 lit. a DSGVO (Einwilligung durch aktive Freischaltung).</p>

  <!-- MODULE:3d-maps -->

  <hr>

  <h3>5.10 Newsletter</h3>

  <!-- MODULE:brevo -->

  <hr>

  <h2>6. Empfänger von Daten und Auftragsverarbeiter</h2>

  <p>Ihre personenbezogenen Daten werden nur an Dritte weitergegeben, soweit dies zur Erfüllung der genannten Zwecke erforderlich ist, eine Rechtsgrundlage besteht oder Sie eingewilligt haben.</p>

  <h3>Auftragsverarbeiter</h3>

  <p>Die folgenden Dienstleister verarbeiten Daten in unserem Auftrag:</p>

  <table><thead>
  <tr>
  <th>Auftragsverarbeiter</th>
  <th>Zweck</th>
  <th>Sitz</th>
  </tr>
  </thead><tbody>
  <tr>
  <td>demokratie.today</td>
  <td>Technischer Betrieb und Wartung der Plattform</td>
  <td>Deutschland</td>
  </tr>
  <tr>
  <td>{{HOSTING_PROVIDER}}</td>
  <td>Hosting der Plattform</td>
  <td>Deutschland</td>
  </tr>
  </tbody></table>

  <!-- SUBPROCESSOR_LIST -->

  <p>Mit allen Auftragsverarbeitern wurden Auftragsverarbeitungsverträge gemäß Art. 28 DSGVO geschlossen.</p>

  <h3>Interne Empfänger</h3>

  <p>Innerhalb der Verwaltung des Verantwortlichen erhalten nur diejenigen Stellen Zugriff auf Ihre Daten, die diese zur Durchführung der Beteiligungsverfahren benötigen.</p>

  <hr>

  <h2>7. Datenübermittlung in Drittländer</h2>

  <p>Die Plattform wird auf Servern in Deutschland betrieben. Eine Übermittlung Ihrer Daten in Länder außerhalb der Europäischen Union bzw. des Europäischen Wirtschaftsraums (Drittländer) findet grundsätzlich nicht statt.</p>

  <!-- DRITTLAND_LIST -->

  <hr>

  <h2>8. Dauer der Datenspeicherung</h2>

  <p>Wir speichern Ihre personenbezogenen Daten nur so lange, wie es für die Erfüllung der jeweiligen Verarbeitungszwecke erforderlich ist oder gesetzliche Aufbewahrungspflichten bestehen.</p>

  <table><thead>
  <tr>
  <th>Datenkategorie</th>
  <th>Speicherdauer</th>
  </tr>
  </thead><tbody>
  <tr>
  <td>Server-Logdaten (IP-Adressen)</td>
  <td>Maximal 7 Tage</td>
  </tr>
  <tr>
  <td>Kontodaten (Benutzername, E-Mail)</td>
  <td>Solange das Nutzerkonto besteht</td>
  </tr>
  <tr>
  <td>Optionale Profilangaben</td>
  <td>Solange das Nutzerkonto besteht</td>
  </tr>
  <tr>
  <td>Verifizierungsdaten</td>
  <td>Solange das Nutzerkonto besteht</td>
  </tr>
  <tr>
  <td>Öffentliche Beiträge</td>
  <td>Nach Kontolöschung anonymisiert</td>
  </tr>
  <tr>
  <td>Kontaktanfragen</td>
  <td>Nach abschließender Bearbeitung</td>
  </tr>
  <tr>
  <td>Session-Daten</td>
  <td>Nach Ende der Browsersitzung</td>
  </tr>
  </tbody></table>

  <p>Bei Löschung Ihres Nutzerkontos werden Ihre personenbezogenen Daten gelöscht. Öffentliche Beiträge (Vorschläge, Kommentare) werden anonymisiert und bleiben ohne Personenbezug auf der Plattform erhalten, um die Nachvollziehbarkeit der Beteiligungsergebnisse zu gewährleisten.</p>

  <hr>

  <h2>9. Ihre Rechte als betroffene Person</h2>

  <p>Sie haben gegenüber dem Verantwortlichen folgende Rechte hinsichtlich Ihrer personenbezogenen Daten:</p>

  <h3>Auskunftsrecht (Art. 15 DSGVO)</h3>

  <p>Sie haben das Recht, Auskunft über Ihre bei uns gespeicherten personenbezogenen Daten zu verlangen, einschließlich der Verarbeitungszwecke, der Kategorien der Daten und der Empfänger.</p>

  <h3>Recht auf Berichtigung (Art. 16 DSGVO)</h3>

  <p>Sie haben das Recht, die unverzügliche Berichtigung unrichtiger oder die Vervollständigung unvollständiger personenbezogener Daten zu verlangen.</p>

  <h3>Recht auf Löschung (Art. 17 DSGVO)</h3>

  <p>Sie haben das Recht, die Löschung Ihrer personenbezogenen Daten zu verlangen, sofern die Voraussetzungen des Art. 17 DSGVO vorliegen. Sie können Ihr Nutzerkonto jederzeit selbstständig über die Kontoeinstellungen der Plattform löschen.</p>

  <h3>Recht auf Einschränkung der Verarbeitung (Art. 18 DSGVO)</h3>

  <p>Sie haben unter bestimmten Voraussetzungen das Recht, die Einschränkung der Verarbeitung Ihrer Daten zu verlangen.</p>

  <h3>Recht auf Datenübertragbarkeit (Art. 20 DSGVO)</h3>

  <p>Sie haben das Recht, die Sie betreffenden personenbezogenen Daten in einem strukturierten, gängigen und maschinenlesbaren Format zu erhalten oder deren Übermittlung an einen anderen Verantwortlichen zu verlangen.</p>

  <h3>Widerspruchsrecht (Art. 21 DSGVO)</h3>

  <p>Sie haben das Recht, aus Gründen, die sich aus Ihrer besonderen Situation ergeben, jederzeit gegen die Verarbeitung Ihrer Daten Widerspruch einzulegen, sofern die Verarbeitung auf Art. 6 Abs. 1 lit. e DSGVO beruht.</p>

  <h3>Beschwerderecht bei der Aufsichtsbehörde (Art. 77 DSGVO)</h3>

  <p>Unbeschadet eines anderweitigen Rechtsbehelfs steht Ihnen das Recht auf Beschwerde bei einer Datenschutz-Aufsichtsbehörde zu. Sie können sich hierzu an die Aufsichtsbehörde Ihres Aufenthaltsortes, Ihres Arbeitsplatzes oder des Ortes des mutmaßlichen Verstoßes wenden.</p>

  <hr>

  <h2>10. Widerruf der Einwilligung</h2>

  <p>Soweit die Verarbeitung Ihrer personenbezogenen Daten auf einer Einwilligung beruht (Art. 6 Abs. 1 lit. a DSGVO), haben Sie das Recht, diese Einwilligung jederzeit mit Wirkung für die Zukunft zu widerrufen. Die Rechtmäßigkeit der bis zum Widerruf erfolgten Verarbeitung bleibt davon unberührt.</p>

  <p>Den Widerruf können Sie per E-Mail an {{STADT_EMAIL}} oder an den/die Datenschutzbeauftragte/n unter {{DSB_EMAIL}} richten. Darüber hinaus können Sie bestimmte Einwilligungen (z. B. Cookie-Einstellungen) jederzeit über die Plattform selbst ändern.</p>

  <hr>

  <h2>11. Stand und Änderungen dieser Datenschutzerklärung</h2>

  <p>Diese Datenschutzerklärung hat den Stand: <strong>{{STAND_DATUM}}</strong>.</p>

  <p>Wir behalten uns vor, diese Datenschutzerklärung anzupassen, um sie an geänderte Rechtslagen oder Änderungen der Plattform anzupassen. Die jeweils aktuelle Fassung ist auf der Plattform abrufbar.</p>
  HTML
end

def generate_content(page)
  page.title = I18n.t("pages.privacy.title")
  page.content = privacy_page_content
  page.save!
end

unless SiteCustomization::Page.exists?(footer_key: "privacy")
  page = SiteCustomization::Page.new(slug: "privacy", footer_key: "privacy", footer_position: 1,
                                     status: "published")
  page.print_content_flag = true
  I18n.with_locale(:de) { generate_content(page) }
end
