# Architektur

Dieses Dokument gibt einen groben Überblick über den Aufbau der Plattform
„Öffentlichkeitsbeteiligung in der Stadt Regensburg“. Es beschreibt die
Komponenten und deren Zusammenspiel auf konzeptioneller Ebene und richtet
sich an Personen, die verstehen möchten, wie die Plattform aufgebaut ist –
ohne technische Vorkenntnisse vorauszusetzen. Es ersetzt keine detaillierte
technische Dokumentation; Informationen zum laufenden Betrieb finden sich im
[Betriebshandbuch](BETRIEBSHANDBUCH.md).

## Überblick

Die Plattform ist eine webbasierte Anwendung nach dem klassischen
Client-Server-Modell: Nutzerinnen und Nutzer greifen mit einem gewöhnlichen
Webbrowser auf die Plattform zu, die gesamte Verarbeitung findet auf den
Servern statt. Es muss keine Software installiert werden, und die Plattform
funktioniert auf Desktop-Rechnern, Tablets und Smartphones gleichermaßen.

Die Anwendung basiert auf einer angepassten Version der bewährten
Open-Source-Beteiligungssoftware Consul, die international von zahlreichen
Städten und Institutionen eingesetzt wird, und wurde für die Anforderungen
deutscher Kommunen umfassend weiterentwickelt.

```
             Nutzer:in (Browser)
                     │  verschlüsselte Verbindung (HTTPS)
                     ▼
       Rails-Anwendung (Anwendungslogik + Seitenaufbau)
                     │
   ┌─────────────────┼──────────────────────────────┐
   │                 │                              │
   ▼                 ▼                              ▼
PostgreSQL     Hintergrunddienste              Externe Dienste
(Datenbank)    (E-Mail-Versand,                ├─ Kartendienste (Mapbox/
                zeitversetzte                  │  Leaflet, kommunale Geo-
                Aufgaben)                      │  portale / Masterportal)
                                               ├─ Anmeldedienste
                                               │  (z. B. BundID, BayernID)
                                               ├─ E-Mail-Versanddienst
                                               └─ KI-Dienst (optional)
```

## Komponenten

### Backend (Anwendungslogik)

Das Herzstück der Plattform ist die serverseitige Anwendung auf Basis von
Ruby on Rails, einem seit vielen Jahren etablierten Framework für
Webanwendungen. Das Backend verwaltet die Nutzerkonten und Berechtigungen,
steuert die Beteiligungsprozesse (z. B. Vorschläge, Abstimmungen,
Bürgerhaushalt, Anliegenmanagement) und die zugehörigen Abläufe – etwa
welche Phasen ein Beteiligungsverfahren durchläuft und wer wann was tun
darf.

### Frontend (Benutzeroberfläche)

Die Seiten werden serverseitig aufgebaut und fertig an den Browser
ausgeliefert. Das hat praktische Vorteile: Die Plattform funktioniert auch
auf älteren Geräten und bei langsamen Verbindungen zuverlässig, ist gut für
Suchmaschinen auffindbar und erfüllt die Anforderungen an Barrierefreiheit
leichter. Interaktive Elemente (z. B. Karten, Filter) werden gezielt im
Browser ergänzt. Der Verwaltungsbereich für Kommunen folgt dem
KERN-UX-Standard, dem einheitlichen Gestaltungsstandard für digitale
Verwaltungsangebote in Deutschland.

### Datenbank

Alle Inhalte, Nutzerdaten und Beteiligungsergebnisse werden in einer
PostgreSQL-Datenbank gespeichert – einem ausgereiften, quelloffenen
Datenbanksystem, das auch in kritischen Umgebungen des öffentlichen Sektors
breit eingesetzt wird. Die Datenbank ist nicht öffentlich erreichbar;
Zugriffe erfolgen ausschließlich über die Anwendung. Zur Datensicherung
siehe das [Betriebshandbuch](BETRIEBSHANDBUCH.md).

### Hintergrundverarbeitung

Aufgaben, die nicht sofort erledigt sein müssen – etwa der Versand von
E-Mails oder aufwendigere Auswertungen – werden von der Anwendung an eine
Warteschlange übergeben und von Hintergrunddiensten abgearbeitet. So bleibt
die Plattform für Nutzerinnen und Nutzer auch bei hoher Last schnell
bedienbar.

### Kartendienst

Ortsbezogene Beteiligung (z. B. Anliegen auf einer Stadtkarte, Projekte in
bestimmten Stadtteilen) wird über eine interaktive Kartendarstellung auf
Basis von Mapbox/Leaflet umgesetzt. Zusätzlich können kommunale Geoportale
(Masterportal) und kommunale Geodaten eingebunden werden, sodass die
Beteiligung auf dem vertrauten Kartenmaterial der jeweiligen Kommune
stattfindet.

### Anmeldung und Identität

Neben der klassischen Registrierung mit E-Mail-Adresse unterstützt die
Plattform die Anbindung staatlicher Anmeldedienste wie BundID und BayernID.
Kommunen können damit steuern, welches Vertrauensniveau für welche
Beteiligungsform erforderlich ist – von der offenen Teilnahme bis zur
verifizierten Identität, etwa bei Abstimmungen.

### Benachrichtigungen

Zu relevanten Beteiligungsereignissen (z. B. Statusänderungen eines
Anliegens, Bestätigungen, Antworten auf eigene Beiträge) versendet die
Plattform E-Mails über einen externen E-Mail-Versanddienst. Der Versand
erfolgt über die Hintergrundverarbeitung, sodass er die Bedienung der
Plattform nicht verlangsamt.

### KI-gestützte Funktionen (optional)

Ergänzend stehen optionale, KI-gestützte Funktionen zur Verfügung – etwa
die automatisierte Zusammenfassung und thematische Bündelung großer Mengen
von Beiträgen oder ein Assistenzsystem, das Nutzerinnen und Nutzer bei der
Beteiligung unterstützt. Diese Funktionen greifen auf einen externen
KI-Dienst zu und sind je Kommune einzeln aktivierbar; ohne ausdrückliche
Aktivierung findet keine Übermittlung an den KI-Dienst statt. Die konkrete
Ausgestaltung (Prompts, Modellauswahl, Anbindung) ist nicht Bestandteil
dieses Dokuments.

## Instanzen je Kommune

Jede Kommune erhält eine eigene, auf sie zugeschnittene Instanz der
Plattform mit eigenem Erscheinungsbild, eigener Domain und eigener
Modulauswahl. Die Daten verschiedener Kommunen werden nicht vermischt.
Gleichzeitig teilen sich alle Instanzen dieselbe Codebasis, sodass
Weiterentwicklungen und Sicherheitsaktualisierungen allen Kommunen
zugutekommen.

## Trennung von Quellcode und Konfiguration

Der Quellcode im Repository umfasst die Anwendungslogik der Plattform.
Konfigurationswerte, Zugangsdaten und instanzspezifische Anpassungen
(z. B. für einzelne Kommunen) werden nicht im Quellcode, sondern in
separaten, nicht öffentlichen Konfigurationsartefakten verwaltet. Diese
Trennung stellt sicher, dass der Quellcode offengelegt werden kann, ohne
schützenswerte Informationen preiszugeben. Details zu Bereitstellung und
Betrieb finden sich im [Betriebshandbuch](BETRIEBSHANDBUCH.md).

## Datenfluss (vereinfacht)

1. Eine Nutzerin oder ein Nutzer ruft die Plattform im Browser über eine
   verschlüsselte Verbindung auf.
2. Das Backend verarbeitet die Anfrage, prüft die Berechtigungen und liest
   bzw. schreibt die zugehörigen Daten in der Datenbank.
3. Für ortsbezogene Inhalte wird die Kartendarstellung eingebunden, bei
   Bedarf mit Kartenmaterial des kommunalen Geoportals.
4. Bei relevanten Ereignissen (z. B. einer Statusänderung) stellt das
   Backend eine Benachrichtigung in die Warteschlange, die von der
   Hintergrundverarbeitung als E-Mail versendet wird.

## Hinweis

Diese Übersicht dient dem allgemeinen Verständnis der Systemarchitektur.
Detaillierte Installations-, Konfigurations- und Betriebsschritte sind
nicht Bestandteil dieses öffentlichen Dokuments.
