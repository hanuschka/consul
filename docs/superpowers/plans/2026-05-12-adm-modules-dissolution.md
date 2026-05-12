# Adm::Modules-Auflösung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den Admin-Menüpunkt „Module" komplett auflösen und Modul-Einstellungen (An/Aus-Toggle, Intro-Text, Notice, Ansprechpartner) jeweils ins zuständige Bereichs-Dashboard verschieben.

**Architecture:** Wiederverwendbarer `Adm::SectionSettingsComponent` (ViewComponent) bündelt Toggle + Intro/Notice-Form + Ansprechpartner-Liste; ein zentraler `Adm::SectionSettingsController` handhabt das Update. Pro Bereich (Projekts, Ideas, DeficiencyReports, LandingPages, Moderation, Valuation) wird der Component in einen neuen oder bestehenden „Einstellungen"-Reiter eingehängt. „Übersichtsseiten" (Budget/Polls/Proposals) ziehen als neuer Reiter unter Adm::Projekts.

**Tech Stack:** Ruby on Rails 7, ViewComponent, Foundation 6, Stimulus, Turbo, RSpec/Capybara (nur falls existierend ergänzen).

**Branch:** `CON-2804` (bestehende Branch — der Plan baut auf der bereits gestarteten Tab-Konsolidierung auf).

**Wichtig:** Keine Commits zwischen Tasks — nach jeder Phase aufsammeln, Commit-Message = Branch-Name (`CON-2804`). Hard Rules: kein hardcoded i18n, alle neuen Strings in `config/locales/kern/de/` + `kern/en/`. Manuelle Browser-Verifikation am Ende.

---

## File Structure (Übersicht)

**Neu zu erstellen:**
- `app/components/adm/section_settings_component.rb` — ViewComponent: Toggle + Intro/Notice-Form + Contact-People-Liste
- `app/components/adm/section_settings_component.html.erb` — Template
- `app/controllers/adm/section_settings_controller.rb` — `update` Action für Intro/Notice
- `app/controllers/adm/section_contact_people_controller.rb` — umgezogen aus `adm/modules/contact_people_controller.rb`
- `app/views/adm/section_contact_people/` — Views aus `adm/modules/contact_people/` umgezogen
- `app/controllers/adm/projekts/settings_controller.rb` — neuer Settings-Reiter für Projekts
- `app/views/adm/projekts/settings/show.html.erb` — Settings-View für Projekts
- `app/controllers/adm/projekts/overviews_controller.rb` — „Übersichtsseiten"-Reiter unter Projekts
- `app/views/adm/projekts/overviews/show.html.erb` — Overviews-View
- `app/controllers/adm/landing_pages/settings_controller.rb` — neuer Settings-Reiter für LandingPages
- `app/views/adm/landing_pages/settings/show.html.erb`
- `app/controllers/adm/moderation/settings_controller.rb` — neuer Settings-Reiter für Moderation
- `app/views/adm/moderation/settings/show.html.erb`
- `app/controllers/adm/valuation/settings_controller.rb` — neuer Settings-Reiter für Valuation
- `app/views/adm/valuation/settings/show.html.erb`

**Zu modifizieren:**
- `app/components/adm/menu_component.rb` — Modul-Eintrag entfernen
- `app/components/adm/projekts/menu_component.rb` — Settings + Übersichtsseiten-Reiter
- `app/components/adm/ideas/menu_component.rb` — Settings-Reiter bleibt, aber Pfad ggf. neu
- `app/components/adm/deficiency_reports/menu_component.rb` — Settings-Reiter bleibt
- `app/components/adm/landing_pages/menu_component.rb` — neuer Settings-Reiter
- `app/components/adm/moderation/menu_component.rb` — neuer Settings-Reiter
- `app/components/adm/valuation/menu_component.rb` — neuer Settings-Reiter
- `app/views/adm/ideas/ideas/settings.html.erb` — SectionSettings-Component einbinden
- `app/views/adm/deficiency_reports/deficiency_reports/settings.html.erb` — dito
- `app/views/adm/home/show.html.erb` — Info-Block „Aktive Module"
- `app/controllers/adm/home_controller.rb` — Module-Status für Info-Block laden
- `config/routes/adm.rb` — `resources :modules` entfernen, `resources :section_contact_people` + `resources :section_settings` neu
- `config/routes/adm/projekts.rb` — `settings` + `overviews` Routes
- `config/routes/adm/landing_pages.rb` — `settings` Route
- `config/routes/adm/moderation.rb` — `settings` Route
- `config/routes/adm/valuation.rb` — `settings` Route
- `config/locales/kern/de/adm/modules.yml` — wird leer / gelöscht
- `config/locales/kern/en/adm/modules.yml` — dito
- `config/locales/kern/de/adm/section_settings.yml` — Sektionen-Labels (existiert vermutlich schon)
- `config/locales/kern/de/adm/projekts.yml`, `ideas.yml`, `deficiency_reports.yml`, `landing_pages.yml`, `moderation.yml`, `valuation.yml`, `home.yml` — Reiter-Labels + Section-Settings-Texte (EN analog)

**Zu löschen (Phase 4):**
- `app/controllers/adm/modules_controller.rb`
- `app/controllers/adm/modules/contact_people_controller.rb`
- `app/views/adm/modules/` (gesamtes Verzeichnis)
- `config/locales/kern/de/adm/modules.yml` und `kern/en/adm/modules.yml` (falls leer)

---

## Phase 1 — Reusable Infrastructure

### Task 1: SectionSettingsComponent erstellen

**Files:**
- Create: `app/components/adm/section_settings_component.rb`
- Create: `app/components/adm/section_settings_component.html.erb`
- Reference: `app/views/adm/modules/show.html.erb` (Vorlage für den Block)

- [ ] **Step 1: Component-Klasse erstellen**

`app/components/adm/section_settings_component.rb`:

```ruby
class Adm::SectionSettingsComponent < ApplicationComponent
  # section: String — eine der SectionSetting::SECTIONS (oder beliebige Section-ID)
  # module_setting_keys: Array<String> — Setting-Keys (Booleans) die als Toggles oben gerendert werden (kann leer sein)
  def initialize(section:, module_setting_keys: [])
    @section = section
    @module_settings = module_setting_keys.map { |key| Setting.find_by(key: key) }.compact
    @section_setting = SectionSetting.for_section(section) if SectionSetting::SECTIONS.include?(section)
    @section_contact_people = SectionContactPerson.for_section(section) if SectionContactPerson::SECTIONS.include?(section)
  end

  private

    attr_reader :section, :module_settings, :section_setting, :section_contact_people

    def render?
      module_settings.any? || section_setting.present? || section_contact_people.present?
    end
end
```

- [ ] **Step 2: Template erstellen**

`app/components/adm/section_settings_component.html.erb`:

```erb
<div class="adm-section-settings">
  <% if module_settings.any? %>
    <div class="mb-3">
      <% module_settings.each do |setting| %>
        <%= render Adm::AttributeEditorComponent.new(setting, :value, :boolean) %>
      <% end %>
    </div>
  <% end %>

  <% if section_setting.present? %>
    <div class="kern-container--form">
      <%= form_with model: section_setting, url: helpers.adm_section_setting_path(section), method: :patch do |f| %>
        <%= render Kern::FormFieldComponent.new(
          label: t("adm.section_settings.edit.intro_text"),
          hint: t("adm.section_settings.edit.intro_text_hint"),
          stacked: true
        ) do %>
          <%= f.text_area :intro_text, label: false, maxlength: 350, class: "kern-input", rows: 3,
              placeholder: t("adm.section_settings.edit.intro_text_placeholder"),
              value: section_setting.intro_text %>
        <% end %>

        <%= render Kern::FormFieldComponent.new(
          label: t("adm.section_settings.edit.notice_message"),
          hint: t("adm.section_settings.edit.notice_message_hint"),
          stacked: true
        ) do %>
          <%= f.text_area :notice_message, label: false, class: "kern-input", rows: 4,
              placeholder: t("adm.section_settings.edit.notice_message_placeholder") %>
        <% end %>

        <%= render Kern::FormFieldComponent.new(
          label: t("adm.section_settings.edit.notice_active"),
          hint: t("adm.section_settings.edit.notice_active_hint"),
          divider: false
        ) do %>
          <%= f.check_box :notice_active, label: t("adm.section_settings.edit.notice_active") %>
        <% end %>

        <%= form_submit_button %>
      <% end %>
    </div>
  <% end %>

  <% if section_contact_people.present? %>
    <div class="mt-5">
      <h2 class="kern-heading fs-4 mb-3"><%= t("adm.section_settings.contact_people.title") %></h2>

      <%= helpers.new_resource_link(helpers.new_adm_section_contact_person_path(section: section), t("adm.section_settings.contact_people.new_link")) %>

      <% if section_contact_people.any? %>
        <div class="kern-table-responsive" tabindex="0">
          <table class="kern-table">
            <thead class="kern-table__head">
              <tr class="kern-table__row">
                <th scope="col" class="kern-table__header"><%= t("adm.section_settings.contact_people.table.name") %></th>
                <th scope="col" class="kern-table__header"><%= t("adm.section_settings.contact_people.table.role") %></th>
                <th scope="col" class="kern-table__header"><%= t("adm.section_settings.contact_people.table.email") %></th>
                <th scope="col" class="kern-table__header"><%= t("adm.section_settings.contact_people.table.phone") %></th>
                <th scope="col" class="kern-table__header"><%= t("adm.section_settings.contact_people.table.actions") %></th>
              </tr>
            </thead>
            <tbody class="kern-table__body">
              <% section_contact_people.each do |contact_person| %>
                <tr id="<%= helpers.dom_id(contact_person) %>" class="kern-table__row">
                  <td scope="row" class="kern-table__header"><%= contact_person.name %></td>
                  <td class="kern-table__cell"><%= contact_person.role %></td>
                  <td class="kern-table__cell"><%= contact_person.email %></td>
                  <td class="kern-table__cell"><%= contact_person.phone %></td>
                  <td class="kern-table__cell">
                    <%= render Kern::Table::ActionsComponent.new do |actions| %>
                      <% actions.with_action(label: t("adm.section_settings.contact_people.table.edit"), url: helpers.edit_adm_section_contact_person_path(contact_person), icon: "edit", style: :edit) %>
                      <% actions.with_action(
                        label: t("adm.section_settings.contact_people.table.delete"),
                        url: helpers.adm_section_contact_person_path(contact_person),
                        icon: "delete", style: :delete,
                        data: { turbo_method: :delete, turbo_confirm: t("adm.section_settings.contact_people.table.delete_confirm") }
                      ) %>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% else %>
        <%= helpers.empty_state(
          title: t("adm.section_settings.contact_people.empty_title"),
          description: t("adm.section_settings.contact_people.empty_description"),
          icon: "contact_phone",
          link_url: helpers.new_adm_section_contact_person_path(section: section),
          link_text: t("adm.section_settings.contact_people.new_link")
        ) %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Browser-Smoke-Test ist hier noch nicht möglich — Component wird in Task 4 erstmals gerendert. Manuell prüfen: Rails-Boot okay (`bin/rails runner 'Rails.application.eager_load!; puts "ok"'`)**

Expected: `ok` ohne Fehler. Falls Fehler: Syntax in Component fixen.

---

### Task 2: Adm::SectionSettingsController (Update-Action)

**Files:**
- Create: `app/controllers/adm/section_settings_controller.rb`
- Modify: `config/routes/adm.rb` (Resource hinzufügen)

- [ ] **Step 1: Controller anlegen**

`app/controllers/adm/section_settings_controller.rb`:

```ruby
module Adm
  class SectionSettingsController < Adm::BaseController
    def update
      @section_setting = SectionSetting.for_section(params[:id])
      authorize [:adm, @section_setting]

      @section_setting.author = current_user

      if @section_setting.update(section_setting_params)
        redirect_back fallback_location: adm_root_path,
                      notice: t("adm.section_settings.flash.updated")
      else
        redirect_back fallback_location: adm_root_path,
                      alert: @section_setting.errors.full_messages.to_sentence
      end
    end

    private

      def section_setting_params
        params.require(:section_setting).permit(:intro_text, :notice_message, :notice_active)
      end
  end
end
```

- [ ] **Step 2: Route hinzufügen**

In `config/routes/adm.rb` neben die anderen Top-Level-Resourcen einfügen:

```ruby
resources :section_settings, only: [:update]
```

Damit ergibt sich `PATCH /adm/section_settings/:id` mit `:id = section-name` (z.B. `projekts`).

- [ ] **Step 3: Policy prüfen — gibt es `SectionSettingPolicy`?**

Run: `find /home/weinm/consul/app/policies -name "section_setting*"`

Erwartet: `app/policies/adm/section_setting_policy.rb` (oder Tier). Falls nicht vorhanden, eine minimale erstellen, die `Adm::ModulesPolicy` widerspiegelt (Authorization wie auf der jetzigen Modul-Seite — Admins only):

```ruby
module Adm
  class SectionSettingPolicy < Adm::BasePolicy
    def update?
      user.administrator?
    end
  end
end
```

- [ ] **Step 4: Routes prüfen**

Run: `bin/rails routes | grep section_settings`

Expected: `PATCH /adm/section_settings/:id`

---

### Task 3: SectionContactPeople umziehen (Controller + Views + Routes)

**Files:**
- Create: `app/controllers/adm/section_contact_people_controller.rb`
- Create: `app/views/adm/section_contact_people/` (Verzeichnis)
- Modify: `config/routes/adm.rb`

- [ ] **Step 1: Controller umziehen mit angepassten Redirects**

`app/controllers/adm/section_contact_people_controller.rb`:

```ruby
module Adm
  class SectionContactPeopleController < Adm::BaseController
    before_action :load_section_contact_person, only: [:edit, :update, :destroy]

    SECTION_REDIRECTS = {
      "projekts"            => :adm_projekts_settings_path,
      "ideas"               => :adm_ideas_settings_path,
      "deficiency_reports"  => :adm_deficiency_reports_settings_path,
      "landing_pages"       => :adm_landing_pages_settings_path,
      "moderation"          => :adm_moderation_settings_path,
      "valuation"           => :adm_valuation_settings_path
    }.freeze

    def new
      @section_contact_person = SectionContactPerson.new(section: params[:section])
      authorize [:adm, @section_contact_person]
      @breadcrumbs = form_breadcrumbs
    end

    def create
      @section_contact_person = SectionContactPerson.new(section_contact_person_params)
      authorize [:adm, @section_contact_person]

      if @section_contact_person.save
        redirect_to redirect_path_for(@section_contact_person.section), notice: t(".success")
      else
        @breadcrumbs = form_breadcrumbs
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @breadcrumbs = form_breadcrumbs
    end

    def update
      if @section_contact_person.update(section_contact_person_params)
        redirect_to redirect_path_for(@section_contact_person.section), notice: t(".success")
      else
        @breadcrumbs = form_breadcrumbs
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section_contact_person.destroy!
      redirect_to redirect_path_for(@section_contact_person.section), notice: t(".success")
    end

    def search
      authorize [:adm, SectionContactPerson], :create?
      @users = params[:search].to_s.length >= 2 ? User.search(params[:search]).limit(4) : User.none
    end

    private

      def load_section_contact_person
        @section_contact_person = SectionContactPerson.find(params[:id])
        authorize [:adm, @section_contact_person]
      end

      def section_contact_person_params
        params.require(:section_contact_person).permit(:user_id, :section, :role, :email, :phone, :position)
      end

      def redirect_path_for(section)
        helper_name = SECTION_REDIRECTS[section]
        helper_name ? send(helper_name) : adm_root_path
      end

      def form_breadcrumbs
        section = @section_contact_person.section
        [
          { name: t("adm.section_settings.sections.#{section}"), url: redirect_path_for(section), icon: "widgets" },
          { name: t("adm.section_settings.contact_people.title") }
        ]
      end
  end
end
```

- [ ] **Step 2: Views aus `adm/modules/contact_people/` nach `adm/section_contact_people/` kopieren**

Run:
```bash
mkdir -p app/views/adm/section_contact_people
cp app/views/adm/modules/contact_people/_form.html.erb app/views/adm/section_contact_people/_form.html.erb
cp app/views/adm/modules/contact_people/new.html.erb app/views/adm/section_contact_people/new.html.erb
cp app/views/adm/modules/contact_people/edit.html.erb app/views/adm/section_contact_people/edit.html.erb
cp app/views/adm/modules/contact_people/search.turbo_stream.erb app/views/adm/section_contact_people/search.turbo_stream.erb
```

- [ ] **Step 3: In `_form.html.erb` URL-Helper anpassen**

In `app/views/adm/section_contact_people/_form.html.erb`:

- `adm_modules_contact_people_path` → `adm_section_contact_people_path`
- `adm_modules_contact_person_path(@section_contact_person)` → `adm_section_contact_person_path(@section_contact_person)`
- `search_adm_modules_contact_people_path` → `search_adm_section_contact_people_path`

- [ ] **Step 4: Routes hinzufügen**

In `config/routes/adm.rb` ergänzen:

```ruby
resources :section_contact_people, only: [:new, :create, :edit, :update, :destroy] do
  post :search, on: :collection
end
```

- [ ] **Step 5: i18n-Keys umziehen**

Bestehende `adm.modules.contact_people.*`-Keys in `config/locales/kern/de/adm/modules.yml` zu `adm.section_settings.contact_people.*` in einer neuen oder bestehenden `config/locales/kern/de/adm/section_settings.yml` verschieben. Englisch analog. (Prüfen ob `adm/section_settings.yml` schon existiert — wenn ja, ergänzen.)

Run: `ls /home/weinm/consul/config/locales/kern/de/adm/section_settings.yml`

Falls nicht vorhanden, neu anlegen. Die Keys, die der Component erwartet (siehe Task 1):
- `adm.section_settings.contact_people.title`
- `adm.section_settings.contact_people.new_link`
- `adm.section_settings.contact_people.empty_title`
- `adm.section_settings.contact_people.empty_description`
- `adm.section_settings.contact_people.table.{name,role,email,phone,actions,edit,delete,delete_confirm}`
- `adm.section_settings.contact_people.search.{select,no_results}`
- `adm.section_settings.contact_people.form.{submit,select_user,search_user_placeholder,select_section,hints.*}`
- `adm.section_settings.contact_people.new.title`
- `adm.section_settings.contact_people.edit.title`
- `adm.section_settings.contact_people.create.success` / `update.success` / `destroy.success`

Werte 1:1 aus den `adm.modules.contact_people.*`-Keys übernehmen.

- [ ] **Step 6: Verifikation — Routes**

Run: `bin/rails routes | grep section_contact_people`

Expected: `adm_section_contact_people` (new/create/edit/update/destroy/search) Routes existieren.

---

## Phase 2 — Per-Section Integration

### Task 4: Adm::Ideas Settings-View erweitern

**Files:**
- Modify: `app/views/adm/ideas/ideas/settings.html.erb`

- [ ] **Step 1: SectionSettingsComponent oben einbinden**

Datei wird zu:

```erb
<%= content_for :title, t(".title") %>

<%= render Adm::HeaderComponent.new(title: t(".title"), breadcrumbs: @breadcrumbs) %>

<div class="kern-container my-5">
  <%= render Adm::SectionSettingsComponent.new(
    section: "ideas",
    module_setting_keys: ["process.ideas"]
  ) %>

  <hr class="my-4">

  <%= render Adm::AttributeEditorComponent.new(Setting.find_by!(key: "ideas.show_in_main_menu"), :value, :boolean) %>
  <%# ... bestehende Settings unverändert ... %>
  <%= render Adm::AttributeEditorComponent.new(Setting.find_by!(key: "ideas.external_video"), :value, :boolean) %>
</div>
```

- [ ] **Step 2: Manueller Browser-Check**

Login als Admin → `/adm/ideas/settings` → oben muss erscheinen:
- Toggle „process.ideas"
- Intro-Text / Notice / Notice-Active Form
- Ansprechpartner-Tabelle (oder Empty-State)

Toggle umlegen + Form abschicken → muss persistieren und zurück zum Settings-Reiter leiten.

---

### Task 5: Adm::DeficiencyReports Settings-View erweitern

**Files:**
- Modify: `app/views/adm/deficiency_reports/deficiency_reports/settings.html.erb`

- [ ] **Step 1: SectionSettingsComponent einbinden**

Analog zu Task 4, am Anfang der Datei einfügen:

```erb
<%= content_for :title, t(".title") %>

<%= render Adm::HeaderComponent.new(title: t(".title"), breadcrumbs: @breadcrumbs) %>

<div class="kern-container my-5">
  <%= render Adm::SectionSettingsComponent.new(
    section: "deficiency_reports",
    module_setting_keys: ["process.deficiency_reports"]
  ) %>

  <hr class="my-4">

  <%# ... bestehende deficiency_reports.*-Toggles unverändert ... %>
</div>
```

- [ ] **Step 2: Manueller Browser-Check**

`/adm/deficiency_reports/settings` analog Task 4 prüfen.

---

### Task 6: Adm::Projekts „Einstellungen"-Reiter neu

**Files:**
- Create: `app/controllers/adm/projekts/settings_controller.rb`
- Create: `app/views/adm/projekts/settings/show.html.erb`
- Modify: `app/components/adm/projekts/menu_component.rb`
- Modify: `config/routes/adm/projekts.rb`
- Modify: `config/locales/kern/de/adm/projekts.yml` + EN

- [ ] **Step 1: Controller**

`app/controllers/adm/projekts/settings_controller.rb`:

```ruby
class Adm::Projekts::SettingsController < Adm::Projekts::BaseController
  def show
    authorize [:adm, Setting], :update?

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.settings"), icon: "settings" }
    ]
  end
end
```

- [ ] **Step 2: View**

`app/views/adm/projekts/settings/show.html.erb`:

```erb
<%= content_for :title, t("adm.projekts.menu.items.settings") %>

<%= render Adm::HeaderComponent.new(title: t("adm.projekts.menu.items.settings"), breadcrumbs: @breadcrumbs) %>

<div class="kern-container my-5">
  <%= render Adm::SectionSettingsComponent.new(
    section: "projekts",
    module_setting_keys: [
      "process.projekts",
      "extended_feature.general.enable_projekt_events_page"
    ]
  ) %>
</div>
```

- [ ] **Step 3: Route**

In `config/routes/adm/projekts.rb` innerhalb des `scope :projekts, module: :projekts, as: :projekts`-Blocks (siehe bestehende Struktur). Nach `get :settings` für `projekts#settings` (falls existiert) — neue Route:

```ruby
resource :settings, only: [:show], controller: "settings"
```

→ Pfad: `adm_projekts_settings_path` = `/adm/projekts/settings`

⚠️ **Konflikt prüfen:** In `config/routes/adm/projekts.rb` Zeile 28 existiert bereits `get :settings`. Den Routes-Eintrag inspizieren und entscheiden:
- Wenn er auf einen anderen Controller geht → URL-Konflikt, ggf. den bestehenden umbenennen (z.B. zu `general_settings`, was Zeile 27 schon andeutet).
- Wenn auf den gleichen logischen Bereich → vereinen.

Run: `bin/rails routes | grep "adm/projekts" | grep settings`
Inspect output und mit Maintainer (User Tobias) abklären, bevor weitergemacht wird.

- [ ] **Step 4: Menu-Eintrag hinzufügen**

`app/components/adm/projekts/menu_component.rb` — `menu_items` erweitern um:

```ruby
(if Adm::SettingPolicy.new(current_user, nil).update?
   { label: t("adm.projekts.menu.items.settings"), icon: "settings", path: adm_projekts_settings_path }
 end),
```

- [ ] **Step 5: Locales**

`config/locales/kern/de/adm/projekts.yml` — unter `adm.projekts.menu.items` ergänzen: `settings: Einstellungen`. EN: `settings: Settings`.

- [ ] **Step 6: Browser-Check**

`/adm/projekts/settings` → SectionSettingsComponent sichtbar mit Toggles „process.projekts", „enable_projekt_events_page", Intro/Notice-Form, Ansprechpartner.

---

### Task 7: Adm::Projekts „Übersichtsseiten"-Reiter neu

**Files:**
- Create: `app/controllers/adm/projekts/overviews_controller.rb`
- Create: `app/views/adm/projekts/overviews/show.html.erb`
- Modify: `app/components/adm/projekts/menu_component.rb`
- Modify: `config/routes/adm/projekts.rb`
- Modify: `config/locales/kern/de/adm/projekts.yml` + EN

- [ ] **Step 1: Controller**

`app/controllers/adm/projekts/overviews_controller.rb`:

```ruby
class Adm::Projekts::OverviewsController < Adm::Projekts::BaseController
  def show
    authorize [:adm, Setting], :update?

    @overview_settings = [
      Setting.find_by(key: "extended_feature.general.enable_investments_overview"),
      Setting.find_by(key: "process.polls"),
      Setting.find_by(key: "process.proposals")
    ].compact

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.overviews"), icon: "widgets" }
    ]
  end
end
```

- [ ] **Step 2: View**

`app/views/adm/projekts/overviews/show.html.erb`:

```erb
<%= content_for :title, t("adm.projekts.menu.items.overviews") %>

<%= render Adm::HeaderComponent.new(title: t("adm.projekts.menu.items.overviews"), breadcrumbs: @breadcrumbs) do |header| %>
  <% header.with_hint do %>
    <p class="adm-hint__text"><%= t("adm.projekts.overviews.hint") %></p>
  <% end %>
<% end %>

<div class="kern-container my-5">
  <% @overview_settings.each do |setting| %>
    <%= render Adm::AttributeEditorComponent.new(setting, :value, :boolean) %>
  <% end %>
</div>
```

- [ ] **Step 3: Route**

In `config/routes/adm/projekts.rb` innerhalb des `scope :projekts, module: :projekts, as: :projekts`-Blocks:

```ruby
resource :overviews, only: [:show], controller: "overviews"
```

→ Pfad: `adm_projekts_overviews_path` = `/adm/projekts/overviews`

- [ ] **Step 4: Menu-Eintrag**

In `app/components/adm/projekts/menu_component.rb`:

```ruby
(if Adm::SettingPolicy.new(current_user, nil).update?
   { label: t("adm.projekts.menu.items.overviews"), icon: "widgets", path: adm_projekts_overviews_path }
 end),
```

- [ ] **Step 5: Locales**

`config/locales/kern/de/adm/projekts.yml`:

```yaml
de:
  adm:
    projekts:
      menu:
        items:
          overviews: "Übersichtsseiten"
      overviews:
        hint: "Aktivieren oder deaktivieren Sie hier die öffentlichen Übersichtsseiten für Budgets, Abstimmungen und Vorschläge. Deaktivierte Übersichten sind für Bürger nicht erreichbar — bestehende Inhalte bleiben erhalten."
```

EN analog: `overviews: "Overview pages"` + Hint übersetzt.

- [ ] **Step 6: Browser-Check**

`/adm/projekts/overviews` → drei Toggles, sauber beschriftet, funktional.

---

### Task 8: Adm::LandingPages „Einstellungen"-Reiter neu

**Files:**
- Create: `app/controllers/adm/landing_pages/settings_controller.rb`
- Create: `app/views/adm/landing_pages/settings/show.html.erb`
- Modify: `app/components/adm/landing_pages/menu_component.rb`
- Modify: `config/routes/adm/landing_pages.rb`
- Modify: `config/locales/kern/de/adm/landing_pages.yml` + EN

- [ ] **Step 1-5:** Analog zu Task 6, aber:
- Controller: `Adm::LandingPages::SettingsController` mit `def show; authorize :landing_page, policy_class: ...; @breadcrumbs = [...]; end`
- View: `SectionSettingsComponent.new(section: "landing_pages")` — kein `module_setting_keys` (LandingPages hat keinen Modul-Toggle)
- Route: `resource :settings, only: [:show], controller: "settings"`
- Menu: Eintrag „Einstellungen" mit Icon „settings"
- Locale: `adm.landing_pages.menu.items.settings: Einstellungen` / EN: `Settings`

- [ ] **Step 6: Browser-Check** — `/adm/landing_pages/settings` zeigt Intro/Notice + Ansprechpartner.

---

### Task 9: Adm::Moderation „Einstellungen"-Reiter neu

**Files:** analog zu Task 8 unter `app/controllers/adm/moderation/`, `app/views/adm/moderation/settings/`, etc.

- [ ] **Step 1-5:** Wie Task 8 mit `section: "moderation"`.

- [ ] **Step 6:** Browser-Check unter `/adm/moderation/settings`.

---

### Task 10: Adm::Valuation „Einstellungen"-Reiter neu

**Files:** analog zu Task 8 unter `app/controllers/adm/valuation/`, `app/views/adm/valuation/settings/`, etc.

- [ ] **Step 1-5:** Wie Task 8 mit `section: "valuation"`.

- [ ] **Step 6:** Browser-Check unter `/adm/valuation/settings`.

---

## Phase 3 — Adm::Home Info-Block

### Task 11: „Aktive Module"-Info-Block auf Adm::Home

**Files:**
- Modify: `app/controllers/adm/home_controller.rb`
- Modify: `app/views/adm/home/show.html.erb`
- Modify: `config/locales/kern/de/adm/home.yml` + EN

- [ ] **Step 1: Controller — Modul-Status laden**

In `app/controllers/adm/home_controller.rb`, in `def show` ergänzen:

```ruby
@active_modules = {
  projekts:           Setting["process.projekts"].present?,
  deficiency_reports: Setting["process.deficiency_reports"].present?,
  ideas:              Setting["process.ideas"].present?,
  events:             Setting["extended_feature.general.enable_projekt_events_page"].present?,
  investments:        Setting["extended_feature.general.enable_investments_overview"].present?,
  polls:              Setting["process.polls"].present?,
  proposals:          Setting["process.proposals"].present?
}
```

- [ ] **Step 2: View — Info-Block ergänzen**

In `app/views/adm/home/show.html.erb` als neue Sektion einfügen (Position: nach Intro, vor Users — oder am Ende vor demokratie.today; mit User abstimmen wenn unklar, default: nach Users):

```erb
<%# ── Aktive Module ───────────────────────────────────── %>
<div class="adm-dashboard__section">
  <div class="adm-dashboard__section-header">
    <span class="material-symbols-outlined" aria-hidden="true">widgets</span>
    <h3><%= t("adm.home.show.active_modules.title") %></h3>
  </div>
  <p class="adm-dashboard__hint"><%= t("adm.home.show.active_modules.hint") %></p>
  <ul class="adm-module-status-list">
    <% @active_modules.each do |key, active| %>
      <li class="adm-module-status-list__item">
        <span class="material-symbols-outlined" aria-hidden="true"><%= active ? "check_circle" : "cancel" %></span>
        <span class="adm-module-status-list__label"><%= t("adm.home.show.active_modules.modules.#{key}") %></span>
        <span class="adm-module-status-list__state adm-module-status-list__state--<%= active ? "on" : "off" %>">
          <%= t("adm.home.show.active_modules.state.#{active ? "on" : "off"}") %>
        </span>
      </li>
    <% end %>
  </ul>
</div>
```

- [ ] **Step 3: Minimal-SCSS (optional)**

Falls die existierenden `.adm-dashboard__*` Klassen ausreichen, kein neues SCSS nötig. Sonst kleinen Block in der zugehörigen SCSS-Datei ergänzen — Frontend-Agent fragen (Workflow-Rule: SCSS → hanuschka-dev:frontend ZUERST).

- [ ] **Step 4: Locales**

`config/locales/kern/de/adm/home.yml` — unter `adm.home.show` ergänzen:

```yaml
active_modules:
  title: "Aktive Module"
  hint: "Übersicht, welche Module auf dieser Plattform aktiviert sind. Einstellungen finden Sie im jeweiligen Bereichs-Dashboard."
  state:
    on: "Aktiv"
    off: "Inaktiv"
  modules:
    projekts: "Projekte"
    deficiency_reports: "Mängelmelder"
    ideas: "Ideen"
    events: "Veranstaltungen"
    investments: "Budgetübersicht"
    polls: "Abstimmungsübersicht"
    proposals: "Vorschlagsübersicht"
```

EN analog.

- [ ] **Step 5: Browser-Check** — `/adm` zeigt neue Sektion „Aktive Module" mit korrekten Status-Icons.

---

## Phase 4 — Cleanup

### Task 12: Hauptmenü-Eintrag „Module" entfernen

**Files:**
- Modify: `app/components/adm/menu_component.rb`

- [ ] **Step 1: Zeile entfernen**

In `app/components/adm/menu_component.rb` Zeile 8:

```ruby
{ label: t("adm.menu.items.modules"),       icon: "widgets",          path: adm_modules_path },
```

→ entfernen.

- [ ] **Step 2: Browser-Check** — Hauptmenü zeigt „Module" nicht mehr.

---

### Task 13: Alte Controller, Views, Routes, Locales löschen

**Files:**
- Delete: `app/controllers/adm/modules_controller.rb`
- Delete: `app/controllers/adm/modules/contact_people_controller.rb`
- Delete: `app/controllers/adm/modules/` (Verzeichnis, falls leer)
- Delete: `app/views/adm/modules/` (komplettes Verzeichnis)
- Delete: `app/policies/adm/modules_policy.rb` (falls existent)
- Modify: `config/routes/adm.rb` — `resources :modules` und `resources :modules` Sub-Resourcen entfernen
- Delete: `config/locales/kern/de/adm/modules.yml`
- Delete: `config/locales/kern/en/adm/modules.yml`

- [ ] **Step 1: Routes — `resources :modules` aus `config/routes/adm.rb` entfernen**

Aktuelle Routes-Datei prüfen:
```bash
grep -n "modules" config/routes/adm.rb
```

Alle `modules`-bezogenen Resourcen entfernen.

- [ ] **Step 2: Controller löschen**

```bash
rm app/controllers/adm/modules_controller.rb
rm -r app/controllers/adm/modules
```

- [ ] **Step 3: Views löschen**

```bash
rm -r app/views/adm/modules
```

- [ ] **Step 4: Policy löschen (falls existent)**

```bash
[ -f app/policies/adm/modules_policy.rb ] && rm app/policies/adm/modules_policy.rb
```

- [ ] **Step 5: Locales löschen**

```bash
rm config/locales/kern/de/adm/modules.yml
rm config/locales/kern/en/adm/modules.yml
```

- [ ] **Step 6: i18n-Verbrauchen checken**

```bash
grep -rn "adm\.modules\.\|adm_modules_path\|adm_modules_contact" app/ config/ 2>/dev/null
```

Erwartet: Keine Treffer. Falls doch — adressieren (Restreferenzen umbenennen oder entfernen).

- [ ] **Step 7: Rails-Boot-Smoke-Test**

```bash
bin/rails runner 'Rails.application.eager_load!; puts "ok"'
```

Expected: `ok`. Falls Fehler — Trace folgen und fixen (meist verbleibende Konstantenreferenzen).

---

## Phase 5 — Verification

### Task 14: Multi-Step-Browser-Verifikation

- [ ] **Step 1: Dev-Server starten**

```bash
bin/rails server
```

- [ ] **Step 2: Als Admin einloggen, durchklicken:**

Checkliste:
- [ ] Hauptmenü zeigt KEINEN „Module"-Eintrag
- [ ] `/adm/modules` ergibt 404 (kein Redirect)
- [ ] `/adm` zeigt Info-Block „Aktive Module" mit korrekten Status
- [ ] `/adm/projekts/settings` — Toggle process.projekts + enable_projekt_events_page + Intro/Notice + Ansprechpartner sichtbar und funktional
- [ ] `/adm/projekts/overviews` — drei Toggles (Budget/Polls/Proposals) sichtbar und funktional
- [ ] `/adm/ideas/settings` — Toggle process.ideas + Intro/Notice + Ansprechpartner sichtbar und funktional; bestehende Ideas-Toggles weiter sichtbar
- [ ] `/adm/deficiency_reports/settings` — Toggle process.deficiency_reports + Intro/Notice + Ansprechpartner sichtbar und funktional; bestehende Toggles weiter sichtbar
- [ ] `/adm/landing_pages/settings` — Intro/Notice + Ansprechpartner sichtbar und funktional
- [ ] `/adm/moderation/settings` — Intro/Notice + Ansprechpartner sichtbar und funktional
- [ ] `/adm/valuation/settings` — Intro/Notice + Ansprechpartner sichtbar und funktional
- [ ] In einem beliebigen Settings-Reiter: Neuen Ansprechpartner anlegen → kehrt zum korrekten Settings-Reiter zurück mit Flash-Notice
- [ ] Bearbeiten und Löschen eines Ansprechpartners funktioniert ebenso
- [ ] Intro-Text + Notice-Toggle abschicken → persistiert + Flash-Notice
- [ ] Toggle An/Aus für ein Modul → persistiert; öffentliches Frontend (z.B. `/projekte`) reagiert wie zuvor

- [ ] **Step 3: Mobile-Viewport-Check (< 600px breit)**

DevTools → Mobile Viewport. Alle neuen Settings-Reiter und der Home-Info-Block bleiben lesbar und bedienbar.

- [ ] **Step 4: Accessibility-Smoke-Check**

Settings-Reiter mit Tab-Taste durchnavigieren — Fokus-Reihenfolge sinnvoll, Form-Felder mit Labels verknüpft, Checkboxen per Space toggelbar.

- [ ] **Step 5: Konsistenz-Check via `superpowers:verification-before-completion`**

Bevor „fertig" gesagt wird: Skill `superpowers:verification-before-completion` invocieren und Output abarbeiten.

---

## Commit-Strategie

Pro Phase ein Commit. Branch bleibt `CON-2804`. Commit-Message = Branch-Name (Konvention im Projekt).

```bash
# Phase 1
git add -A
git commit -m "CON-2804"

# Phase 2
git add -A
git commit -m "CON-2804"

# ... usw.
```

Oder am Ende alles in einen Commit zusammenfassen (User-Präferenz fragen, falls Phase-Commits zu granular).

---

## Notizen / Risiken

1. **Konflikt `get :settings` in `config/routes/adm/projekts.rb`**: bereits vorhanden (Zeile 28). Task 6 Step 3 muss vor dem Erstellen der neuen Route geklärt werden — sonst URL-Kollision.
2. **`SectionSetting::SECTIONS` und `SectionContactPerson::SECTIONS`**: Aktuell `%w[ideas deficiency_reports projekts moderation valuation landing_pages]`. Falls neue Bereiche (z.B. „events" mit eigener Intro/Notice) gewünscht, in Models ergänzen — aber NICHT Teil dieses Plans, da User Events einfach unter Projekts hängt.
3. **`Adm::Modules`-Policy + Routes-Helper**: Falls externe Stellen `adm_modules_path` referenzieren (z.B. Mailer, Specs), erscheinen sie in Phase 4 Step 6 Suche. Adressieren statt überspringen.
4. **Bestehende Tests**: Falls `spec/system/adm/modules_spec.rb` oder ähnliches existiert, anpassen / löschen. Run am Anfang: `find spec -path "*modules*" -name "*.rb"`.
5. **Production-DB-Migrationen**: Keine nötig — die Settings-Keys bleiben gleich, nur die UI-URLs ändern sich.
