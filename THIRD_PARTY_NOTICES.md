# Third-Party Notices

Das Mitmachportal nutzt eine Reihe von Open-Source-Komponenten. Diese
Übersicht listet die wesentlichen Abhängigkeiten und deren Lizenzen. Sie
dient der Transparenz gegenüber Kommunen und Öffentlichkeit und ersetzt
keine automatisiert generierte, vollständige Abhängigkeitsliste (siehe
Abschnitt [Vollständigkeit](#vollständigkeit)).

## Basisplattform

Das Mitmachportal ist eine angepasste Version (Fork) der
Open-Source-Beteiligungssoftware
[Consul Democracy](https://github.com/consuldemocracy/consuldemocracy),
die unter der **GNU Affero General Public License v3 (AGPL-3.0)** steht.
Entsprechend wird auch dieses Projekt unter der AGPL v3 veröffentlicht
(siehe [LICENSE-AGPLv3.txt](LICENSE-AGPLv3.txt)).

## Wesentliche Komponenten

### Backend

| Komponente | Zweck | Lizenz |
| --- | --- | --- |
| Ruby on Rails | Web-Framework (Anwendungslogik) | MIT |
| PostgreSQL | Relationale Datenbank | PostgreSQL License |
| Puma | Anwendungsserver | BSD-3-Clause |
| Devise | Anmeldung und Nutzerkonten | MIT |
| CanCanCan / Pundit | Rechte- und Rollenverwaltung | MIT |
| Delayed Job | Hintergrundverarbeitung (z. B. E-Mail-Versand) | MIT |
| Globalize | Mehrsprachigkeit der Inhalte | MIT |
| GraphQL Ruby | Programmierschnittstelle (API) | MIT |
| Dalli / Memcached | Zwischenspeicher (Caching) | MIT / BSD |
| Capistrano | Deployment-Automatisierung | MIT |

### Frontend

| Komponente | Zweck | Lizenz |
| --- | --- | --- |
| Foundation | CSS-Framework (öffentlicher Bereich) | MIT |
| KERN UX (`@kern-ux/native`) | Designsystem des Verwaltungsbereichs (KERN-UX-Standard) | EUPL-1.2 |
| ViewComponent | Komponentenbasiertes View-Layer | MIT |
| Hotwire (Turbo, Stimulus) | Interaktive Elemente im Browser | MIT |
| jQuery / jQuery UI | JavaScript-Bibliothek (öffentlicher Bereich) | MIT |
| Leaflet (inkl. Plugins) | Interaktive Kartendarstellung | BSD-2-Clause |
| Mapbox GL JS (v3) | Kartendarstellung / Geodaten | Proprietär — Mapbox Terms of Service (siehe Hinweis unten) |
| Chart.js | Diagramme und Auswertungen | MIT |
| Sass / esbuild | Build-Werkzeuge für Stylesheets und JavaScript | MIT |

## Hinweis zu Mapbox GL JS

Im Einsatz ist Mapbox GL JS in **Version 3**. Seit Version 2.0 steht
Mapbox GL JS nicht mehr unter einer Open-Source-Lizenz, sondern unter den
proprietären [Mapbox-Nutzungsbedingungen](https://www.mapbox.com/legal/tos);
die Nutzung setzt ein Mapbox-Konto mit Zugangstoken voraus und unterliegt
den Attributions- und Abrechnungsregeln von Mapbox. Wer eine rein
quelloffene Kartendarstellung benötigt, kann die Plattform auf Basis von
Leaflet mit alternativen Kartenanbietern betreiben.

## Hinweis zum E-Mail-Versand

Der E-Mail-Versand erfolgt über das Standardprotokoll SMTP (Bestandteil
von Rails / Action Mailer). Welcher E-Mail-Versanddienst dahinter steht,
ist eine instanzspezifische Konfigurationsentscheidung und keine
Code-Abhängigkeit; es ist keine anbieterspezifische Client-Bibliothek
eingebunden.

## Vollständigkeit

Diese Datei erhebt keinen Anspruch auf Vollständigkeit; sie benennt die
prägenden Komponenten des Technologie-Stacks. Die maßgeblichen,
vollständigen Abhängigkeitslisten sind `Gemfile.lock` (Ruby) und
`package.json` / `package-lock.json` (JavaScript) in diesem Repository.
Für eine automatisiert erzeugte Liste aller direkten und indirekten
Abhängigkeiten samt Lizenzen empfiehlt sich der Einsatz eines
Lizenz-Scanning-Tools (z. B. `license_finder` für Ruby-Abhängigkeiten,
`license-checker` für npm-Pakete).
