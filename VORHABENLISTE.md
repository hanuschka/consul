# Vorhabenliste

Dieses Dokument beschreibt das Modul „Vorhabenliste“ technisch: das
Datenmodell, die Rollen und ihre Rechte, den Ablauf von Entwurf über
Freigabe bis Archiv sowie die Einstellungen, die das Modul mitbringt. Es
richtet sich an Entwicklerinnen und Entwickler, die das Modul warten oder
weiterentwickeln. Den Gesamtaufbau der Plattform beschreibt die
[Architektur](ARCHITEKTUR.md), den Betrieb das
[Betriebshandbuch](BETRIEBSHANDBUCH.md).

Im Code heißt ein Vorhaben durchgehend `MunicipalPlan`, die Vorhabenliste
`municipal_plans`.

## Überblick

Die Vorhabenliste veröffentlicht die Vorhaben der Verwaltung. Die
Sachbearbeitung pflegt sie im Verwaltungsbereich unter `/adm/municipal_plans`,
die Administration gibt sie frei, und die Öffentlichkeit sieht sie unter
`/municipal_plans`. Zu jedem veröffentlichten Vorhaben können Bürgerinnen und
Bürger ohne Anmeldung einen Hinweis senden, der per E-Mail an die zuständige
Sachbearbeitung geht.

Ein freigegebenes Vorhaben wird nie direkt bearbeitet. Änderungen entstehen an
einer Arbeitskopie und werden erst mit der Freigabe öffentlich (siehe
[Ablauf](#ablauf-entwurf-freigabe-archiv)).

## Aufbau im Code

| Bereich | Ort |
|---|---|
| Modelle | `app/models/municipal_plan.rb`, `app/models/municipal_plan/` |
| Öffentliche Seiten | `app/controllers/municipal_plans_controller.rb`, `app/controllers/municipal_plan_notices_controller.rb`, `app/views/custom/municipal_plans/`, `app/components/custom/municipal_plans/` |
| Verwaltungsbereich | `app/controllers/adm/municipal_plans/`, `app/views/adm/municipal_plans/`, `app/components/adm/municipal_plans/` |
| Rechte | `app/policies/adm/municipal_plans/` |
| Abläufe | `app/services/municipal_plans/` |
| Filter und Sortierung | `app/queries/municipal_plans_query.rb`, `app/queries/adm/municipal_plans_query.rb` |
| E-Mails | `app/mailers/municipal_plan_mailer.rb`, `app/views/municipal_plan_mailer/` |
| Übersichtskarte | `app/assets/javascripts/custom/municipal_plans_map.js`, `app/services/municipal_plans/overview_map_service.rb` |
| Routen | `config/routes/municipal_plans.rb`, `config/routes/adm/municipal_plans.rb` |
| Geplante Aufgabe | `lib/tasks/municipal_plans.rake`, `config/schedule.rb` |
| Texte | `config/locales/custom/*/municipal_plans.yml`, `config/locales/kern/*/adm/municipal_plans.yml` |
| Tests | `spec/` – alle Dateien mit `municipal_plan` im Namen |

## Datenmodell

### Vorhaben (`municipal_plans`)

| Feld | Bedeutung |
|---|---|
| `status` | `draft` (Entwurf), `published` (Veröffentlicht) oder `archived` (Archiviert). Standard: `draft`. |
| `version` | Versionsnummer, z. B. `1.4`. Beginnt bei `0.1` und wird automatisch gesetzt (siehe [Versionsnummer und Aktualisierungsdatum](#versionsnummer-und-aktualisierungsdatum)). |
| `content_updated_at` | Aktualisierungsdatum: Tag der letzten inhaltlichen Änderung. Wird automatisch gesetzt. |
| `given_order` | Redaktionelle Reihenfolge in der Liste. Leer bedeutet: ans Ende. |
| `formal_participation` | Bürgerbeteiligung formell (ja/nein). |
| `informal_participation` | Bürgerbeteiligung informell (ja/nein). |
| `contact_name` | Name der Ansprechperson. |
| `contact_phone` | Telefon der Ansprechperson. |
| `contact_email` | E-Mail der Ansprechperson. |
| `system_mailbox_email` | Systempostfach für Hinweise. Erhält zusätzlich jeden Hinweis zu diesem Vorhaben. |
| `internal_notes` | Interne Notizen. Nur im Verwaltungsbereich sichtbar. |
| `responsible_type`, `responsible_id` | Zuständige Sachbearbeitung: entweder eine Person (`MunicipalPlan::Officer`) oder eine Bearbeitergruppe (`MunicipalPlan::OfficerGroup`). |
| `submitted_at` | Zeitpunkt, zu dem das Vorhaben zur Freigabe eingereicht wurde. Leer, solange nichts auf Freigabe wartet. |
| `released_plan_id` | Nur bei einer Arbeitskopie gesetzt: verweist auf das freigegebene Vorhaben, zu dem die Kopie gehört. |
| `archive_on` | Geplantes Archivdatum. |
| `released_at` | Zeitpunkt der letzten Freigabe. Wird bei jeder Freigabe gesetzt. |
| `tsv` | Suchindex für die Volltextsuche. Wird automatisch gepflegt. |
| `created_at`, `updated_at` | Technische Zeitstempel. |

### Übersetzbare Felder (`municipal_plan_translations`)

Diese Felder werden je Sprache gespeichert (Spalte `locale`).

| Feld | Bedeutung |
|---|---|
| `title` | Titel des Vorhabens. Das einzige Pflichtfeld eines Entwurfs. |
| `short_description` | Kurze Beschreibung (Rich Text). |
| `further_information` | Weitere Informationen (Rich Text). |
| `last_resolution` | Letzter Beschluss. |
| `processing_status` | Aktueller Bearbeitungsstand. |
| `next_steps` | Geplanter Zeitpunkt, nächste Schritte. |
| `costs` | Kosten, soweit bezifferbar. |
| `formal_participation_reason` | Begründung zur formellen Bürgerbeteiligung. |
| `informal_participation_reason` | Begründung zur informellen Bürgerbeteiligung. |
| `contact_role` | Funktion der Ansprechperson. |

### Zugeordnete Daten

| Tabelle / Modell | Inhalt |
|---|---|
| `municipal_plan_district_assignments` (`MunicipalPlan::DistrictAssignment`) | Betroffene Ortsteile. Verknüpft ein Vorhaben mit `RegisteredAddress::District`. Höchstens 4 je Vorhaben (`MunicipalPlan::MAX_DISTRICTS`). |
| `municipal_plan_topic_assignments` (`MunicipalPlan::TopicAssignment`) | Schwerpunktmäßig betroffene Themen. |
| `municipal_plan_topics` (`MunicipalPlan::Topic`) | Die Themen selbst. Feld `given_order` für die Reihenfolge, übersetzbarer `name` in `municipal_plan_topic_translations`. Ein Thema, das noch einem Vorhaben zugeordnet ist, kann nicht gelöscht werden. |
| `municipal_plan_links` (`MunicipalPlan::Link`) | Links und Dokumente: `title`, `url` (beide Pflicht) und `given_order`. |
| `map_locations` | Kartenposition des Vorhabens, über das gemeinsame `Mappable`-Modul der Plattform. |
| `municipal_plan_notices` (`MunicipalPlan::Notice`) | Hinweise aus der Öffentlichkeit: `name` (optional, höchstens 100 Zeichen), `email` (Pflicht, höchstens 255 Zeichen), `body` (Pflicht, höchstens 5000 Zeichen). Werden mit dem Vorhaben gelöscht. |
| `municipal_plan_officers` (`MunicipalPlan::Officer`) | Sachbearbeitung. Macht ein bestehendes Benutzerkonto (`user_id`, eindeutig) zur Sachbearbeitung. |
| `municipal_plan_officer_groups` (`MunicipalPlan::OfficerGroup`) | Bearbeitergruppen: `name` (Pflicht). Eine gemeinsame Adresse für Hinweise wird nicht an der Gruppe, sondern je Vorhaben als Systempostfach hinterlegt. |
| `municipal_plan_officer_group_assignments` (`MunicipalPlan::OfficerGroupAssignment`) | Mitgliedschaft einer Sachbearbeitung in einer Bearbeitergruppe. |
| `projekts.municipal_plan_id` | Verweis eines Beteiligungsprojekts auf das Vorhaben, aus dem es entstanden ist (siehe [Umwandlung in ein Beteiligungsprojekt](#umwandlung-in-ein-beteiligungsprojekt)). Wird beim Löschen des Vorhabens geleert. |

Eine Sachbearbeitung oder Bearbeitergruppe, der noch Vorhaben zugeordnet sind,
kann nicht gelöscht werden.

### Änderungsprotokoll

Änderungen an Vorhaben werden mit dem Gem `audited` protokolliert und im
Verwaltungsbereich je Vorhaben angezeigt. Erfasst werden alle übersetzbaren
Felder sowie `formal_participation`, `informal_participation`, die
Kontaktfelder, `system_mailbox_email`, `internal_notes`, `status`,
`given_order`, die Zuständigkeit und `released_at`
(`MunicipalPlan::AUDITED_ATTRIBUTES`).

Änderungen an einer Arbeitskopie werden zunächst an der Kopie protokolliert.
Bei der Freigabe werden diese Einträge auf das freigegebene Vorhaben
übertragen, sodass das Protokoll jede Änderung mit ihrer Urheberin oder ihrem
Urheber zeigt. Die Übertragung der Inhalte selbst wird nicht noch einmal
protokolliert. Stattdessen hält ein eigener Eintrag „Freigegeben am“ fest,
wer wann freigegeben hat. Anlage und Löschung der Kopie erscheinen nicht im
Protokoll.

## Rollen und Rechte

Das Modul kennt drei Rollen.

- **Administration:** Benutzerkonten mit der Plattformrolle Administrator.
- **Sachbearbeitung:** Benutzerkonten mit einem Eintrag in
  `municipal_plan_officers`. Die Administration legt sie im
  Verwaltungsbereich unter „Sachbearbeitung“ an, über die E-Mail-Adresse
  eines bestehenden Kontos.
- **Öffentlichkeit:** alle Besucherinnen und Besucher, auch ohne Anmeldung.

Eine Sachbearbeitung ist einem Vorhaben „zugeordnet“, wenn sie selbst als
zuständig eingetragen ist oder Mitglied der zuständigen Bearbeitergruppe ist.

| Aktion | Administration | Sachbearbeitung | Öffentlichkeit |
|---|---|---|---|
| Vorhaben in der Verwaltung auflisten und ansehen | alle | nur zugeordnete, oder alle bei `municipal_plans.officers_see_all` | – |
| Vorhaben anlegen | ja | ja | – |
| Vorhaben bearbeiten, zur Freigabe einreichen, archivieren, Archivierung aufheben, Archivdatum setzen | alle | nur zugeordnete | – |
| Hinweise in der Verwaltung löschen | alle | nur bei zugeordneten | – |
| Vorhaben freigeben | ja | – | – |
| Vorhaben löschen | ja | – | – |
| Redaktionelle Reihenfolge ändern | ja | nur bei `municipal_plans.officers_see_all` | – |
| In ein Beteiligungsprojekt umwandeln | ja | – | – |
| Sachbearbeitung, Bearbeitergruppen und Themen verwalten | ja | – | – |
| Einstellungen der Vorhabenliste ändern | ja | – | – |
| Veröffentlichte und archivierte Vorhaben ansehen | ja | ja | ja |
| Hinweis zu einem veröffentlichten Vorhaben senden | ja | ja | ja |

Die Regeln stehen in `Adm::MunicipalPlans::MunicipalPlanPolicy`. Legt eine
Sachbearbeitung ein Vorhaben ohne Zuständigkeit an, wird sie selbst als
zuständig eingetragen, damit sie es weiter bearbeiten kann.

## Ablauf: Entwurf, Freigabe, Archiv

### Entwurf

Ein neues Vorhaben ist ein Entwurf. Solange es nicht eingereicht ist, braucht
es nur einen Titel. Entwürfe sind öffentlich nicht sichtbar.

### Einreichen

Die Sachbearbeitung reicht den Entwurf zur Freigabe ein. Ab dann muss er
vollständig sein. Pflicht sind:

- Kurze Beschreibung, aktueller Bearbeitungsstand, nächste Schritte
- Zuständige Sachbearbeitung
- Kartenposition
- mindestens ein Ortsteil und mindestens ein Thema

Die Liste steht in `MunicipalPlan::RELEASE_REQUIRED_FIELDS`. Ein Rich-Text-Feld,
das nur leeres Markup enthält, gilt als leer. Beim Einreichen erhält jedes
Administrator-Konto einzeln eine E-Mail
(`MunicipalPlans::SubmissionNotificationService`). Einen Schritt zum Ablehnen
oder Zurückziehen einer Einreichung gibt es nicht.

### Freigeben

Die Administration gibt das Vorhaben frei (`MunicipalPlans::ReleaseService`).
Bei der ersten Freigabe wechselt der Status auf „Veröffentlicht“, und die
Versionsnummer springt auf `1.0`.

### Ändern eines freigegebenen Vorhabens

Wer ein veröffentlichtes oder archiviertes Vorhaben bearbeitet, landet
automatisch in seiner Arbeitskopie (`MunicipalPlans::WorkingCopyService`):

- Die Arbeitskopie ist eine eigene Zeile in `municipal_plans` mit Status
  `draft` und gesetztem `released_plan_id`. Sie ist daher öffentlich nicht
  sichtbar, und für sie gelten dieselben Formulare, Rechte und
  Prüfungen wie für einen Entwurf.
- Die Kopie übernimmt alle Felder des Vorhabens samt Übersetzungen, Ortsteilen,
  Themen, Links und Kartenposition. Status, Versionsnummer,
  Aktualisierungsdatum, Reihenfolge, Einreichungszeitpunkt, Archivdatum und
  Freigabezeitpunkt bleiben am
  freigegebenen Vorhaben (`MunicipalPlans::WorkingCopyService::UNCOPIED_ATTRIBUTES`).
- Zu einem Vorhaben gibt es höchstens eine Arbeitskopie. Eine Arbeitskopie
  hat selbst keine Arbeitskopie.
- Eingereicht wird die Kopie wie ein Entwurf. Enthält sie keine Änderung,
  wird das Einreichen abgelehnt. Die Administration sieht vor der Freigabe
  eine Gegenüberstellung der Änderungen (`MunicipalPlans::ChangeSummaryService`).
- Bei der Freigabe werden die Inhalte der Kopie auf das freigegebene Vorhaben
  übertragen, und die Kopie wird gelöscht. Das Vorhaben behält so seine ID
  und seine öffentliche Adresse, und alle Verweise darauf bleiben gültig.
- Ein archiviertes Vorhaben bleibt nach der Freigabe einer Änderung archiviert.

### Archivieren

Archivierte Vorhaben verschwinden aus der öffentlichen Übersicht und erscheinen
im Archivbereich unter `/municipal_plans/archive`. Ihre Detailseite bleibt unter
derselben Adresse erreichbar.

- **Von Hand:** Die Sachbearbeitung archiviert ein Vorhaben im
  Verwaltungsbereich. Ein unvollständiger Entwurf kann nicht archiviert werden.
- **Automatisch:** Ist die Einstellung `municipal_plans.auto_archive` aktiv,
  archiviert die Aufgabe `municipal_plans:apply_due_archiving` täglich um
  3:30 Uhr jedes veröffentlichte Vorhaben, dessen Archivdatum erreicht ist.
  Die Aufgabe läuft auf dem Server mit der Capistrano-Rolle `cron`. Das
  Archivdatum wird am freigegebenen Vorhaben gesetzt und wirkt sofort, ohne
  Freigabe.
- **Aufheben:** Ein bereits freigegebenes Vorhaben kehrt ohne neue Freigabe in
  die Übersicht zurück. Ein Vorhaben, das nie freigegeben war, wird wieder zum
  Entwurf.

### Versionsnummer und Aktualisierungsdatum

- Eine inhaltliche Änderung setzt das Aktualisierungsdatum auf den heutigen
  Tag und erhöht die Nebenversion um eins. Auf `1.9` folgt `1.10`, nicht `2.0`.
  Bei einem Entwurf zählt jedes Speichern, bei einem freigegebenen Vorhaben
  jede Freigabe einer Arbeitskopie mit inhaltlichen Änderungen.
- Die Hauptversion wechselt nur einmal, von `0` auf `1`, bei der ersten
  Freigabe.
- Als inhaltlich gelten alle übersetzbaren Felder, die Beteiligungs- und
  Kontaktfelder, das Systempostfach sowie Ortsteile, Themen und Links.
  Reihenfolge, interne Notizen, Zuständigkeit, Status und Archivdatum ändern
  weder Versionsnummer noch Aktualisierungsdatum.
- Die redaktionelle Reihenfolge wird direkt geschrieben, ohne Prüfungen und
  ohne Einfluss auf die Versionsnummer.

## Hinweise aus der Öffentlichkeit

Das Hinweisformular steht auf der Detailseite jedes veröffentlichten
Vorhabens, nicht bei archivierten. Es braucht keine Anmeldung und ist mit
einem unsichtbaren Honeypot-Feld (`invisible_captcha`) gegen Spam geschützt.

Jeder Hinweis geht als E-Mail an (`MunicipalPlans::NoticeNotificationService`):

- die zuständige Sachbearbeitung, oder jedes Mitglied der zuständigen
  Bearbeitergruppe,
- zusätzlich an das Systempostfach des Vorhabens, sofern eingetragen.

Hinweise bleiben gespeichert, bis sie im Verwaltungsbereich oder mit dem
Vorhaben gelöscht werden.

## Öffentliche Seiten

| Adresse | Inhalt |
|---|---|
| `/municipal_plans` | Übersicht der veröffentlichten Vorhaben |
| `/municipal_plans/archive` | Übersicht der archivierten Vorhaben, mit denselben Filtern |
| `/municipal_plans/:id` | Detailseite eines veröffentlichten oder archivierten Vorhabens |

- **Filter** (Parameter): Ortsteile (`districts[]`), Themen (`topics[]`),
  Beteiligung (`participation[]`), neu/aktualisiert (`recency[]`) und ein
  Zeitraum des Aktualisierungsdatums (`updated_from`, `updated_to`).
- **Suche:** Volltextsuche über `pg_search` mit dieser Gewichtung: Titel vor
  kurzer Beschreibung, vor Beschluss, Bearbeitungsstand und nächsten
  Schritten, vor weiteren Informationen.
- **Sortierung:** Relevanz, redaktionelle Reihenfolge, Aktualisierungsdatum
  oder Titel.
- **Kennzeichen:** „neu“ für Vorhaben, die in den letzten 30 Tagen angelegt
  wurden, und „aktualisiert“ für ältere Vorhaben mit einem
  Aktualisierungsdatum in den letzten 30 Tagen (`MunicipalPlan::RECENCY_WINDOW`).
  Dazu kommen Kennzeichen für formelle und informelle Beteiligung. Archivierte
  Vorhaben erhalten weder „neu“ noch „aktualisiert“.
- **Ansicht:** Kacheln oder Tabelle. Die Wahl wird im Cookie
  `municipal_plans_view` gespeichert.
- **Karte:** Die Übersicht zeigt eine Karte mit den Ortsteilflächen und den
  Kartenpositionen der gefilterten Vorhaben. Ein Klick auf einen Ortsteil
  setzt den Ortsteilfilter. Die Flächen stammen aus den Kartenpositionen von
  `RegisteredAddress::District`. Sind für keinen Ortsteil Flächen hinterlegt,
  wird keine Karte angezeigt. Die Karte funktioniert mit Leaflet und Mapbox.
- **Navigation:** Für das Hauptmenü gibt es einen vordefinierten Eintrag
  (`NavbarItem`), der nur bei aktivem Modul erscheint.

Vorhaben sind nicht Teil der REST-API.

## Umwandlung in ein Beteiligungsprojekt

Die Administration kann aus einem veröffentlichten, freigegebenen Vorhaben ein
Beteiligungsprojekt anlegen (`MunicipalPlan::ProjektConversion`). Das Formular
fragt Titel und Untertitel ab. Beide sind mit dem Titel und der kurzen
Beschreibung des Vorhabens vorbelegt. Der Untertitel ist auf 200 sichtbare
Zeichen und 5 Zeilen begrenzt.

- Übernommen werden die Ortsteile (als Einschränkung auf diese Ortsteile) und
  die Kartenposition. Themen werden nicht übernommen.
- Das neue Projekt ist zunächst deaktiviert. Erst wenn es aktiviert ist,
  verlinkt die Detailseite des Vorhabens auf das Projekt.
- Die Seitenleiste des Projekts verlinkt zurück auf das Vorhaben, solange das
  Modul aktiv und das Vorhaben öffentlich sichtbar ist.
- Ein Vorhaben kann mehrfach umgewandelt werden.

## Einstellungen

Das Modul bringt drei Einstellungen mit (`app/models/custom/setting.rb`). Alle
sind in einer neuen Instanz ausgeschaltet.

| Einstellung | Wirkung |
|---|---|
| `process.municipal_plans` | Schaltet das Modul öffentlich ein. Ist sie aus, antworten alle öffentlichen Seiten und das Hinweisformular mit `403 Forbidden`, und der Menüeintrag und der Rückverweis in Projekten entfallen. Der Verwaltungsbereich bleibt unabhängig davon nutzbar. |
| `municipal_plans.officers_see_all` | Die Sachbearbeitung sieht im Verwaltungsbereich alle Vorhaben statt nur der ihr zugeordneten und darf die redaktionelle Reihenfolge ändern. Bearbeiten darf sie weiterhin nur zugeordnete Vorhaben. |
| `municipal_plans.auto_archive` | Vorhaben werden am hinterlegten Archivdatum automatisch archiviert (siehe [Archivieren](#archivieren)). |

Die Administration schaltet sie im Verwaltungsbereich unter „Vorhabenliste →
Einstellungen“ (`/adm/municipal_plans/settings`). Die Seite ist der
Administration vorbehalten (`Adm::MunicipalPlans::SettingPolicy`).

Wie bei allen Einstellungen der Plattform legt die Bereitstellung fehlende
Einträge mit ihrem Standardwert selbst an. Eine Migration ist dafür nicht
nötig.
