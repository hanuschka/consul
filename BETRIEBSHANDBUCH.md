# Betriebshandbuch

Dieses Dokument beschreibt auf grober Ebene, wie die Plattform
„Öffentlichkeitsbeteiligung in der Stadt Regensburg“ betrieben wird. Es
richtet sich an Personen, die sich einen Überblick über die Betriebsabläufe
verschaffen möchten – etwa Verantwortliche in Kommunen oder Prüfstellen –
und ersetzt keine vollständige Installations- oder Administrationsanleitung.
Konkrete Infrastrukturdetails, Zugangsdaten und interne Prozesse sind
bewusst nicht Bestandteil dieses öffentlichen Dokuments.

## Aufbau der Plattform

Die Plattform ist eine webbasierte Anwendung, die vollständig im Browser
genutzt wird – Bürgerinnen und Bürger müssen keine Software installieren. Die
Plattform besteht im Wesentlichen aus drei Bausteinen:

- **Webanwendung**: die eigentliche Beteiligungsplattform mit öffentlichem
  Bereich (Projekte, Beteiligungsverfahren) und geschütztem
  Verwaltungsbereich für Redaktion und Administration.
- **Datenbank**: alle Inhalte, Beiträge und Einstellungen werden in einer
  PostgreSQL-Datenbank gespeichert.
- **Hintergrunddienste**: zeitversetzte Aufgaben wie E-Mail-Versand oder
  Auswertungen laufen im Hintergrund, damit die Plattform für Nutzerinnen und
  Nutzer jederzeit schnell reagiert.

Die Software basiert auf der bewährten Open-Source-Plattform Consul und wird
für die Anforderungen des deutschen öffentlichen Sektors kontinuierlich
weiterentwickelt.

## Hosting

Die Plattform wird auf einer verwalteten Server-Infrastruktur in einem
professionellen Rechenzentrum betrieben. Der Betrieb umfasst die laufende
Pflege der Server, die Einspielung von Sicherheitsaktualisierungen auf
Systemebene sowie die Überwachung der Verfügbarkeit. Die Verbindung zur
Plattform ist durchgehend verschlüsselt (HTTPS). Die konkrete Infrastruktur,
Zugangsdaten und Deployment-Konfiguration sind nicht Bestandteil dieses
Dokuments.

## Bereitstellung (Deployment)

Änderungen am Quellcode durchlaufen einen kontrollierten
Bereitstellungsprozess, bevor sie auf der produktiven Instanz aktiv werden:

1. **Entwicklung**: Neue Funktionen und Fehlerbehebungen werden zunächst in
   einer Entwicklungsumgebung umgesetzt und dort getestet.
2. **Review**: Jede Änderung wird vor der Freigabe geprüft (Vier-Augen-Prinzip
   auf Code-Ebene).
3. **Bereitstellung**: Die Auslieferung auf die produktive Instanz erfolgt
   automatisiert über das etablierte Werkzeug Capistrano. Der automatisierte
   Ablauf stellt sicher, dass jede Bereitstellung reproduzierbar und
   nachvollziehbar ist und im Fehlerfall auf den vorherigen Stand
   zurückgekehrt werden kann.

Bereitstellungen erfolgen in der Regel ohne wahrnehmbare Unterbrechung des
laufenden Betriebs. Konkrete Zielumgebungen, Zugangsdaten und der genaue
Freigabeprozess sind nicht Bestandteil dieses Dokuments.

## Konfiguration

Jede Kommune erhält eine auf sie zugeschnittene Instanz. Instanzspezifische
Einstellungen – zum Beispiel Design und Farbgebung, Textbausteine, aktivierte
Beteiligungsmodule oder angebundene Anmeldeverfahren – werden getrennt vom
Quellcode über umgebungsspezifische Konfigurationswerte verwaltet. Dieser
Ansatz hat zwei Vorteile:

- Alle Instanzen profitieren gleichermaßen von Weiterentwicklungen und
  Sicherheitsaktualisierungen der gemeinsamen Codebasis.
- Kommunale Anpassungen bleiben bei Updates erhalten und müssen nicht
  erneut vorgenommen werden.

Viele Inhalte und Einstellungen können darüber hinaus von berechtigten
Personen der Kommune direkt im Verwaltungsbereich der Plattform gepflegt
werden, ohne dass eine technische Änderung erforderlich ist. Details zur
Konfigurationsstruktur und den konkreten Werten sind nicht Teil dieses
öffentlichen Dokuments.

## Datensicherung

Für die PostgreSQL-Datenbank bestehen regelmäßige, automatisierte
Datensicherungen. Die Sicherungen werden getrennt vom Produktivsystem
aufbewahrt, sodass Daten auch bei einem Ausfall des Servers wiederhergestellt
werden können. Die Wiederherstellbarkeit der Sicherungen wird im Rahmen der
Betriebsprozesse berücksichtigt. Details zu Frequenz, Aufbewahrungsdauer und
dem Wiederherstellungsprozess werden intern gehandhabt und sind hier bewusst
nicht aufgeführt.

## Monitoring

Der Betrieb der Plattform wird durchgehend mittels eines Fehler- und
Performance-Monitorings überwacht. Dazu gehören insbesondere:

- **Fehlerüberwachung**: Auftretende Anwendungsfehler werden automatisch
  erfasst und dem Betriebsteam gemeldet, häufig bevor Nutzerinnen und Nutzer
  sie überhaupt bemerken.
- **Performance-Überwachung**: Antwortzeiten und Auslastung werden laufend
  beobachtet, um Engpässe frühzeitig zu erkennen.
- **Verfügbarkeitsüberwachung**: Die Erreichbarkeit der Plattform wird
  regelmäßig automatisiert geprüft.

Alarmierung und Eskalation erfolgen über interne Prozesse.

## Wartung und Weiterentwicklung

Die Plattform wird laufend gepflegt. Dazu gehören sicherheitsrelevante
Aktualisierungen der eingesetzten Softwarekomponenten, Fehlerbehebungen sowie
funktionale Weiterentwicklungen. Geplante Wartungsarbeiten, die den Betrieb
spürbar beeinträchtigen könnten, werden – soweit möglich – außerhalb der
Hauptnutzungszeiten durchgeführt und vorab angekündigt.

## Software-Stückliste (SBOM)

Die Datei `sbom.cdx.json` im Wurzelverzeichnis des Repositorys enthält eine
Software-Stückliste im Format CycloneDX (JSON). Sie listet die eingesetzten
Ruby-Gems aus `Gemfile.lock` und die npm-Pakete aus `package-lock.json` mit
Version, Package-URL (purl) und – soweit ermittelbar – Lizenz auf.

Die Stückliste wird mit [Trivy](https://github.com/aquasecurity/trivy) erzeugt.
Nach Änderungen an einer der beiden Lock-Dateien wird sie im Wurzelverzeichnis
des Repositorys neu erzeugt:

```bash
trivy fs --format cyclonedx --output sbom.cdx.json --scanners license .
```

Erzeugt mit Trivy 0.74.0; die Ausgabe folgt der CycloneDX-Spezifikation 1.7.

## Datenschutz und Sicherheit

Die Plattform ist auf die Anforderungen des deutschen öffentlichen Sektors
ausgerichtet und datenschutzfreundlich vorkonfiguriert („GDPR by default“).
Personenbezogene Daten werden nur in dem Umfang verarbeitet, der für die
jeweilige Beteiligungsfunktion erforderlich ist. Der Zugriff auf
Verwaltungsfunktionen ist auf berechtigte Personen beschränkt und
rollenbasiert geregelt.

## Support & Ansprechpartner

Bei Fragen zum Betrieb wenden Sie sich an:

**info@demokratie.today** <!-- PLATZHALTER - gewünschte Kontaktadresse eintragen -->

Bitte beschreiben Sie Ihr Anliegen möglichst konkret (betroffene Seite,
Zeitpunkt, ggf. Screenshot) – das beschleunigt die Bearbeitung.

Sicherheitsrelevante Meldungen bitte gemäß [SECURITY.md](SECURITY.md)
einreichen.
