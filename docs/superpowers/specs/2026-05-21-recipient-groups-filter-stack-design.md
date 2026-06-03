# Empfängergruppen — Filter-Stack-Architektur

**Datum:** 2026-05-21
**Jira-Ticket:** CON-2815 (laufende Branch)
**Status:** Design — wartet auf User-Review

## Kontext & Problem

Aktuell unterstützt das Empfängergruppen-System genau zwei Quellen-Typen:

- **`projekts`** → nur `BudgetPhase`-Autoren (5 Kriterien) + projektweite Phasen-Abonnenten
- **`user_roles`** → 3 Methoden (`newsletter_subscriber_ids`, `all_newsletter_subscriber_ids`, `administrators_ids`)

Das Datenmodell `RecipientGroup(name, origin_class_name, origin_class_object_id, access_method)` ist generisch, aber rigide: genau eine Quelle, keine Verfeinerung, keine Kombination. Damit lassen sich viele realistische Use-Cases nicht abbilden:

- Demografisches Targeting (Stadtteil, Altersgruppe, Geschlecht) ist unmöglich
- Andere Phasen-Typen (Proposal, Debate, Voting, Comment, Question, …) sind unsichtbar
- Individual Groups (Kita-Eltern, Vereine etc.) lassen sich nicht adressieren
- Erweiterte Rollen (Moderator, Projekt-Manager, …) fehlen
- Kombinationen wie „Newsletter-Abonnenten UND Geozone Altstadt" gehen nicht

Ziel: Ein erweiterbares Filter-Modell, das die genannten Lücken schließt und gleichzeitig den heute schlanken Use-Case („alle Administratoren") nicht überkompliziert.

## Architektur-Entscheidung

**Filter-Kette mit Operator pro Schritt.** Eine `RecipientGroup` besitzt eine geordnete Liste von `RecipientGroupFilter`-Einträgen. Jeder Filter hat einen `kind` (welche Datenquelle), einen `operator` (`include` / `exclude` / `intersect`) und kind-spezifische `params`. Bei der Auflösung wird die Filterkette sequenziell ausgewertet — der erste Filter erzeugt die Startmenge, jeder weitere modifiziert sie.

Verworfen wurden:

- **Boolean-Tree (AND/OR/NOT-Knoten):** Maximal flexibel, aber Visual Query Builder ist Overengineering für die Admin-Zielgruppe.
- **Eine Quelle + Demografie-Filter:** Einfacher, aber kein echtes UND zwischen verschiedenen Quellen — widerspricht der Anforderung „UND/ODER von Anfang an mitdenken".

## Datenmodell

### Neue Tabelle `recipient_group_filters`

```ruby
create_table :recipient_group_filters do |t|
  t.references :recipient_group, null: false, foreign_key: true, index: true
  t.integer :position, null: false, default: 0
  t.string :kind, null: false
  t.string :operator, null: false, default: "include"
  t.jsonb :params, null: false, default: {}
  t.timestamps
  t.index [:recipient_group_id, :position]
end
```

### Änderungen an `recipient_groups`

- Spalten `origin_class_name`, `origin_class_object_id`, `access_method` bleiben für die Migration kurz erhalten, werden danach in einem Follow-up gedroppt.
- Keine neuen Spalten — `name` bleibt das einzige Top-Level-Attribut.

### Modell-API

```ruby
class RecipientGroup < ApplicationRecord
  has_many :filters, -> { order(:position) },
           class_name: "RecipientGroupFilter",
           dependent: :destroy,
           inverse_of: :recipient_group

  validates :name, presence: true
  validate :first_filter_must_be_include

  def user_emails
    RecipientGroupResolver.new(self).user_emails
  end

  def estimated_count
    RecipientGroupResolver.new(self).count
  end
end

class RecipientGroupFilter < ApplicationRecord
  KINDS = %w[
    newsletter_subscribers role
    phase_authors phase_subscribers comment_authors voting_participants
    geozone plz age_range gender
    individual_group manual_users
  ].freeze

  OPERATORS = %w[include exclude intersect].freeze

  belongs_to :recipient_group

  validates :kind, inclusion: { in: KINDS }
  validates :operator, inclusion: { in: OPERATORS }
  validate :params_valid_for_kind

  acts_as_list scope: :recipient_group
end
```

### Auflösungs-Algorithmus

`RecipientGroupResolver` ist ein PORO mit klarer Verantwortung: nimmt eine `RecipientGroup`, liefert Email-Set + Counts.

```ruby
class RecipientGroupResolver
  def initialize(recipient_group)
    @recipient_group = recipient_group
  end

  def user_emails
    resolve.fetch(:emails)
  end

  def count
    resolve.fetch(:emails).size
  end

  def per_filter_counts
    resolve.fetch(:per_filter)
  end

  private

    def resolve
      @resolve ||= compute
    end

    def compute
      emails = Set.new
      per_filter = []

      @recipient_group.filters.each_with_index do |filter, index|
        resolver = FilterResolvers.for(filter.kind).new(filter.params)
        new_emails = Set.new(resolver.emails)

        emails = case filter.operator
                 when "include"   then index.zero? ? new_emails : emails | new_emails
                 when "exclude"   then emails - new_emails
                 when "intersect" then emails & new_emails
                 end

        per_filter << { id: filter.id, count: emails.size, delta: ... }
      end

      { emails: emails.to_a, per_filter: per_filter }
    end
end
```

Erster Filter wird immer als `include` interpretiert (Validation oben erzwingt das).

## Filter-Kinds (Phase 1 — 12 Kinds)

Jeder Kind = eine eigene Resolver-Klasse in `app/services/recipient_group/filter_resolvers/`. Single Responsibility: gegeben `params`, liefere `emails`.

| Kind | Cluster | Params | Quelle |
|---|---|---|---|
| `newsletter_subscribers` | A | `include_unregistered: bool` | `User.actual.where(newsletter: true)` + optional `UnregisteredNewsletterSubscriber.confirmed` |
| `role` | A | `role: string` (`administrator`/`moderator`/`valuator`/`projekt_manager`/`idea_manager`/`officing_manager`/`deficiency_report_manager`) | `User.joins(role.to_sym)` |
| `phase_authors` | A | `projekt_phase_id`, `criterion`-String — Phasentyp bestimmt erlaubte Werte (siehe Tabelle unten) | Phasen-spezifischer Scope am `ProjektPhase`-Subtyp |
| `phase_subscribers` | A | `projekt_phase_id` ODER `projekt_id` (= alle Phasen) | `ProjektPhaseSubscription`-Join |
| `comment_authors` | A | `commentable_type` (`Projekt`/`ProjektPhase`/global), `commentable_id` optional | `Comment.where(commentable: …).pluck(:user_id)` |
| `voting_participants` | A | `projekt_phase_id` (muss VotingPhase sein) | Voting-Records der Phase |
| `geozone` | B | `geozone_ids: [int]` | `User.where(geozone_id: …)` |
| `plz` | B | `plz_list: [string]` (Exact-Match auf String-PLZ; Range-Logik kommt in Phase 2) | `User.where(plz: …)` |
| `age_range` | B | `age_range_id` ODER `{min_age, max_age}` | Berechnung über `date_of_birth` |
| `gender` | B | `gender: m/f/d` | `User.where(gender: …)` |
| `individual_group` | C | `individual_group_value_ids: [int]` | `UserIndividualGroupValue`-Join |
| `manual_users` | E | `user_ids: [int]` | `User.where(id: …)` |

**Phase 2 (späterer Spec):** `registered_address`, `manual_emails`, `csv_upload`, `verification_level`, `activity_*` (Engagement-Filter), `deficiency_reporters`, `idea_authors`.

### `phase_authors` — erlaubte `criterion`-Werte je Phasentyp

| Phasentyp | Erlaubte `criterion`-Werte | Datenquelle |
|---|---|---|
| `ProjektPhase::BudgetPhase` | `feasible`, `unfeasible`, `selected`, `winners`, `not_winners` | `authors_of_<criterion>_ids` (bereits existent) |
| `ProjektPhase::ProposalPhase` | `all` | `Proposal.where(projekt_phase_id: id).pluck(:author_id)` |
| `ProjektPhase::DebatePhase` | `all` | `Debate.where(projekt_phase_id: id).pluck(:author_id)` |
| `ProjektPhase::ArgumentPhase` | `all` | analog, Argument-Autoren |
| `ProjektPhase::QuestionPhase` | `all` (Frage-Antwortende) | über existierende Answer-Relation |

Andere Phasentypen (Milestone, Event, POI, Iframe, Livestream, Newsfeed, Legislation, Stats, Newsletter) haben in Phase 1 **keine** `phase_authors`-Quelle — UI filtert die Phasenauswahl entsprechend. Wer Comment-Phasen-Autoren will, nutzt den eigenen Kind `comment_authors`; für Voting analog `voting_participants`.

### Resolver-Vertrag

```ruby
module RecipientGroup::FilterResolvers
  class Base
    def initialize(params)
      @params = params.with_indifferent_access
    end

    def emails
      raise NotImplementedError
    end

    def self.for(kind)
      const_get(kind.camelize)
    end
  end

  class NewsletterSubscribers < Base
    def emails
      base = User.actual.where(newsletter: true).pluck(:email)
      base += UnregisteredNewsletterSubscriber.confirmed.pluck(:email) if @params[:include_unregistered]
      base.compact.uniq
    end
  end

  # … weitere 11 Resolver-Klassen analog
end
```

Resolver liefern direkt Email-Strings (statt User-IDs), damit `UnregisteredNewsletterSubscriber`-Quellen ohne Sonderfall integrieren. Für die Set-Operationen sind Email-Strings der natürliche Vergleichsschlüssel.

## UI-Pattern: Filter-Stack

One-Page-Editor (kein Wizard mehr), sortierbare Liste von Filter-Karten:

```
┌─ Empfängergruppe: [Newsletter-Q2_______________] ────────────┐
│                                                              │
│  ┌ Filter #1  [▼ Hinzufügen]  Newsletter-Abonnenten     [⋮] ┐│
│  │   ☐ Unregistrierte einbeziehen                          │ │
│  │                                          → 1.247 Personen│ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌ Filter #2  [▼ Schnittmenge] Geozone                  [⋮] ┐│
│  │   Stadtteil(e): Altstadt × Maxvorstadt ×                │ │
│  │                                            → 312 Personen│ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌ Filter #3  [▼ Ausschließen] Rolle                    [⋮] ┐│
│  │   Rolle: Administratoren                                │ │
│  │                                              → −5 Personen│
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  [ + Filter hinzufügen ]                                     │
│                                                              │
│  Endgröße: 307 Empfänger                [Vorschau] [Speichern]│
└──────────────────────────────────────────────────────────────┘
```

### UI-Mechanik

- **Sortierung:** Drag-Handle (`[⋮]`) oder ↑↓-Buttons. Reihenfolge bestimmt die Auflösung. Erster Filter zeigt Operator als „Startmenge" statt Dropdown.
- **Operator-Dropdown:** Standard `include` (Hinzufügen). Beim Hinzufügen eines neuen Filters per Default `intersect` ab dem zweiten — das ist der erwartete Default („Newsletter UND Geozone").
- **Kind-Dropdown:** Liste der 12 Filter-Kinds, gruppiert nach Cluster (Quellen / Demografie / Sondergruppen / Manuell).
- **Params-Felder:** Kind-spezifisches Teil-Formular, das bei Kind-Wechsel ausgetauscht wird (Turbo-Frame).
- **Live-Counter:** Pro Filter zeigt sich `→ N Personen` (Gesamt nach diesem Filter) und `Δ` (Änderung gegenüber vorherigem Schritt). Footer zeigt Endgröße. Recompute via Turbo-Stream beim Speichern jedes Filter-Feldes (debounced).
- **Vorschau:** Modal mit ersten 50 Emails + Gesamtzahl.

### Technische Komponenten

- `Adm::RecipientGroupFiltersController` mit Turbo-Stream-Actions: `create`, `update`, `destroy`, `reorder`, `recount`.
- Neue ViewComponent: `Adm::RecipientGroupFilterCardComponent` pro Filter-Karte.
- Stimulus-Controller `adm-newsletters--filter-stack` für Drag-Sort + debounced Recount.

## Migration der bestehenden RecipientGroups

Data-Migration übersetzt jede bestehende Gruppe in genau einen `RecipientGroupFilter`:

| Alt (`origin_class_name`, `access_method`) | Neuer Filter |
|---|---|
| `User`, `newsletter_subscriber_ids` | `kind: newsletter_subscribers, params: { include_unregistered: false }` |
| `User`, `all_newsletter_subscriber_ids` | `kind: newsletter_subscribers, params: { include_unregistered: true }` |
| `User`, `administrators_ids` | `kind: role, params: { role: "administrator" }` |
| `Projekt`, `any_phase_subscribers_ids` | `kind: phase_subscribers, params: { projekt_id: <id> }` |
| `ProjektPhase`, `authors_of_*_ids` | `kind: phase_authors, params: { projekt_phase_id: <id>, criterion: "feasible"/"winners"/… }` |

Operator immer `include`, Position `0`. Migration läuft als reguläre Rails-Migration, transaktional.

Nach erfolgreicher Migration werden die alten Spalten `origin_class_name`, `origin_class_object_id`, `access_method` in einem Follow-up-Ticket aus dem Schema entfernt. Bis dahin: deprecated, nicht mehr beschrieben.

## Locales

Alle neuen Strings nach `config/locales/kern/de/adm/recipient_groups.yml` und `config/locales/kern/en/adm/recipient_groups.yml`. Struktur:

```yaml
de:
  adm:
    recipient_groups:
      filters:
        operators:
          include: Hinzufügen
          exclude: Ausschließen
          intersect: Schnittmenge
        kinds:
          newsletter_subscribers: Newsletter-Abonnenten
          role: Rolle
          phase_authors: Phasen-Autoren
          phase_subscribers: Phasen-Abonnenten
          comment_authors: Kommentatoren
          voting_participants: Abstimmungs-Teilnehmer
          geozone: Stadtteil
          plz: Postleitzahl
          age_range: Altersgruppe
          gender: Geschlecht
          individual_group: Sondergruppe
          manual_users: Manuelle Auswahl
        groups:
          sources: Quellen
          demographics: Demografie
          special: Sondergruppen
          manual: Manuell
        labels:
          # kind-spezifische Field-Labels …
        counter:
          total: "Endgröße: %{count} Empfänger"
          delta_plus: "+%{count}"
          delta_minus: "−%{count}"
```

Hard-Rule beachten: kein Gendern (kein „Nutzer:innen"), generisches Maskulinum.

## Edge Cases & Validierungen

- **Leere Filter-Kette:** RecipientGroup ohne Filter → `user_emails == []`, Versand nicht möglich, Warnung im UI.
- **Erster Filter ist `exclude` / `intersect`:** Validation-Error („Erster Filter muss eine Quelle hinzufügen").
- **Filter mit ungültigen `params`:** kind-spezifische Validierung im `RecipientGroupFilter`-Model. Resolver dürfen explodieren, wenn validate vorher OK war.
- **Phase-Referenzen werden gelöscht:** `RecipientGroupFilter`-Records mit `kind in [phase_authors, phase_subscribers, voting_participants, comment_authors]` müssen via DB-Constraint oder Service-Hook gekippt werden, wenn der referenzierte Datensatz verschwindet. Vorschlag Phase 1: kein Hard-Constraint, sondern beim Resolver `try/rescue` mit Logging — Phase 2 sauberer machen.
- **Performance:** Bei <50k aktiven Usern ist In-Memory-Set-Algebra ausreichend. Caching der Counts pro Filter via `Rails.cache` (5-Minuten-TTL) verhindert Repeat-Berechnung beim Recount. Bei >50k Usern wird der Live-Counter durch einen expliziten „Empfänger zählen"-Button ersetzt (keine automatische Berechnung beim Tippen). Echte SQL-basierte Set-Operationen für >100k Users sind explizit out-of-scope für Phase 1.

## Tests

- **Unit:** Pro Resolver-Klasse ein Spec mit Fixtures, das die Email-Liefermenge prüft.
- **Service:** `RecipientGroupResolver`-Spec mit Filter-Ketten unterschiedlicher Operatoren.
- **Integration:** `Adm::RecipientGroupFiltersController`-Specs (Turbo-Stream-Responses).
- **Data-Migration:** Spec mit allen Alt-Kombinationen → Neuer Filter.
- **System:** Capybara/System-Spec für den Filter-Stack-Builder (Drag-Sort weglassen — JS-System-Tests sind in diesem Repo fragil; stattdessen direkt Reorder-Action testen).

## Out-of-Scope (Phase 2 — eigener Spec)

- Filter-Kinds `registered_address`, `manual_emails`, `csv_upload`, `verification_level`, `activity_*`, `deficiency_reporters`, `idea_authors`
- Boolean-Tree-Mode (verschachtelte Gruppen)
- Filter-Templates / Wiederverwendbare Filter-Bausteine
- A/B-Test-Splitting innerhalb einer Empfängergruppe
- Geplante Versendung mit zeitabhängiger Filter-Auflösung (Snapshot vs Live)
- PLZ-Range-Logik (Phase 1 nur Exact-Match)
- Drop der alten Spalten `origin_class_name`/`origin_class_object_id`/`access_method` (Follow-up nach erfolgter Migration)

## Offene Punkte für Implementation-Plan

- Konkrete `acts_as_list`-Variante (Gem) prüfen — alternativ einfache Position-Logik selbst
- Stimulus-Controller-Skelett für Drag-Sort: bestehendes Pattern im Repo finden (z.B. `app/javascript/controllers/…`)
- Counter-Recompute-Debounce-Intervall (Vorschlag: 400ms)
- Rollen-Liste vollständig verifizieren (Mike fragen, ob `deficiency_report_manager` korrekt heißt)
