# Changelog

Notable changes to the Consul Projekt API, most recent first.

## 2026-11-19

### Every content field readable and writable

Clients now read and write the content fields the platform has, following
one rule for personal data: read-only clients get what the public site shows,
admin clients also the workflow data, and no client gets login data, private
staff contact data, form submissions, event registrations or single votes
(only counts).

**Texts per language.** Responses carry `translations`, keyed by locale, next
to the fields in the request language; request bodies accept the same shape.
`translations_attributes` keeps working where it worked before. A language
the instance doesn't offer answers `422`. When a request writes more than one
language (top-level fields count as the request language), machine
translation stays off, so it never overwrites what the client wrote.
Validation errors of a single language come as
`translations.<locale>.<attribute>`.

```
PATCH /api/proposals/1
{ "proposal": { "translations": {
    "de": { "title": "Neuer Radweg" },
    "en": { "title": "New cycle path" } } } }
```

**Map locations** return id, coordinates, altitude, zoom, approximated
address, `features` (drawn shapes as GeoJSON), `pin_color`,
`show_admin_shape`, `rendering_library` and `mapbox_style_id`. Writes accept
`features` as an object or a JSON string; an update without the location's id
changes the existing location instead of replacing it.

**External ids.** Proposals, budget investments and point of interest pins
have `external_source` and `external_id`, set on create and unique per phase
(investments: per budget). A duplicate answers `422`. Records imported from
Masterportal report `masterportal` and the feature id.

### New endpoints

- `GET /api/projekt_phases/{id}/projekt_labels`, `/sentiments`,
  `/masterportal_collections` (admin clients also get `endpoint_url` and
  `create_domain_records`; import state is never returned).
- `GET /api/formulars/{id}/formular_fields`: labels per language and choices;
  admin clients also the confirmation email settings.
- `GET /api/questions/{question_id}/question_options`.
- `GET /api/deficiency_report_statuses`,
  `GET /api/deficiency_report_subcategories?category_id=`,
  `GET /api/deficiency_report_answer_templates` (admin).
- `GET/PATCH/DELETE /api/milestones/{id}` for milestones of phases,
  proposals, investments and deficiency reports; writes admin-only.
- `POST /api/municipal_plans`, `PATCH /api/municipal_plans/{id}` and
  `PATCH /api/municipal_plans/order` (admin). Each write is released at once
  as a new version, like a release in /adm; a draft is changed in place, and
  a change pending in /adm answers `422`. `archive_on` alone creates no
  version; links are sent as the full list.
- `POST /api/polls/{id}/go_live` (admin) ends test mode like the /adm button.
  Irreversible: answers, voters and booth results of the test phase are
  deleted. A live poll answers `422`.
- `GET /api/polls/{id}/results`: participants, votes and voters per answer,
  weight distributions, anonymous map points. Read-only clients only once the
  poll is live and the phase shows its results.

### New fields

- **Projekts:** `description`, `color`, `icon`, `landing_page_id`,
  `activated`, `tags`, `geozone_affiliation_ids`,
  `registered_address_district_affiliation_ids`, `map_location`; read-only
  `published_at`, `content_updated_at` and the page's `status`,
  `published_at` and `translations`. `color`, `icon`, district ids,
  `map_location_attributes` and page texts are writable.
- **Phases:** every form and button text, `geozone_restriction_ids`,
  `registered_address_district_ids`, `registered_address_street_ids`
  (writable), `mitmachbox_survey_id` for admin clients.
- **Proposals:** `summary` (writable), `retired: true` with reason and
  explanation retires one, `published: true` publishes a draft;
  `on_behalf_of`, `projekt_phase_id`, label icons; `admin_accepted` for admin
  clients.
- **Ideas:** `official_answer` (admin), `timeframe` and
  `votes_needed_for_success` writable (whole numbers ≥ 0);
  `acceptance=pending|all` filter for admin clients. Idea categories:
  `color`, `icon`, `given_order`.
- **Projekt questions:** `comments_enabled`, `show_answers_count`.
  **Events:** `registration_enabled`, `max_attendees`, registration counts;
  confirmation and waitlist email texts for admin clients.
  **Arguments:** `party`.
- **Budgets:** `main_link_text`, `main_link_url`, group and heading names per
  language (written with the budget). Budget phases: `summary`,
  `description`, main link.
- **Investments:** `price_explanation`, `unfeasibility_explanation`,
  `price_first_year`, `duration`, `external_url`, `location`,
  implementation fields, `user_cost_estimate`, `sentiment`, `projekt_labels`,
  read-only `preselected`; admin clients write `winner`, `incompatible`,
  `physical_votes`. Setting `selected` sends the selection email.
- **Polls:** `published`, `live`, `closing_note`, `image`, and the phase's
  display switches (read-only). Questions: nesting, context questions,
  `votation_type` with max votes and rating labels, `map_location`. Answers:
  `images`, `documents`.
- **Milestones:** `custom_date`, `documents`, status `description`.
  **Deficiency reports:** subcategory, `category.warning_text`,
  `official_answer_documents`, `subcategory_id` filter; intake channel for
  admin clients. **Municipal plans:** `given_order`, shapes; admin clients
  also `archive_on`, `released_at`, `responsible`, `pending_working_copy`.
  **POI categories:** `position`, `icon_image_url`.

### Breaking for read-only clients

- Content of a hidden or inactive phase answers `403` on every endpoint,
  milestones, POI pins and categories, formulars and iframes included. Single
  budgets, polls and their questions, answers, phases and investments that
  belong to no phase answer `403` too; the lists already left them out.
- Proposals staff haven't accepted and pending ideas are no longer listed or
  returned (`403`).
- `GET /api/deficiency_reports` answers `403` when a read-only client sends
  `author_id` or `assigned`, instead of an unfiltered list.
- No longer returned: investment `responsible_name` (to anyone),
  `code`, `confidence_score`, `visible_to_valuators` (admin-only), idea
  `official_answer` (admin-only), deficiency report `admin_accepted`,
  `assigned_at` (admin-only) and `hot_score` (to anyone), investment
  `cached_votes_down`.
- Shown only when the public site shows them: investment `winner`,
  `incompatible`, `final_winner`, prices, ballot counts and
  `valuator_explanation`; poll answer vote counts; question answer counts.
- Idea category `ideas_count` and deficiency report category
  `deficiency_reports_count` count published records only.

### Other changes

- Phase `type` is no longer writable on update; nested phase
  `translations_attributes` work again.
- Poll answers can't be renamed or deleted once the poll is live and has
  voters (`422`), as in /adm.
- `GET /api/projekt_phases/{id}/questions` answers `404` for an unknown phase
  or one without questions instead of listing every question.
- Content blocks are written and shown in the instance default language only.
- The OpenAPI schemas list the fields actually returned; documented fields
  that never existed were removed.

## 2026-11-09

### Instance configuration through the API

API clients granted **Zugriff auf Instanz-Konfiguration** in /adm (admin
clients only) can configure the platform under `/api/configuration`:

- `GET`/`PATCH /api/configuration/settings` — metadata, brand and newsletter
  colours, homepage texts, module switches and options, GDPR, uploads, map
  defaults. `GET` lists every configurable key with its type.
- `/api/configuration/images` and `/videos` — every logo and image slot,
  including the new `favicon` slot, and the header videos.
- `/api/configuration/footer_pages`, `/landing_pages`, `/navbar_items`,
  `/content_blocks`, `/content_cards`, `/banners`, `/modal_notifications`,
  `/texts`, `/email_templates`, `/map_layers`, `/geozones`,
  `/tag_categories`, `/age_ranges`, `/individual_groups`.

Values are checked against their type; unknown keys are rejected and nothing
is written when one value is wrong. Every change is audited with the client,
time, and old and new value.

```
PATCH /api/configuration/settings
{ "settings": { "brand_color": "#004a83", "process.ideas": true } }
```

### Breaking: projekt and phase settings only accept known keys and typed values

`PATCH /api/projekts/{id}/update_setting(s)` and
`PATCH /api/projekt_phases/{id}/update_setting(s)` now accept only the keys
the projekt or the phase's type actually has, each checked against its type.
Phase settings no longer create keys that do not exist. Switches take
`true`/`false`; the stored forms `"active"`/`""` keep working.

- `update_setting`: unknown key → `404`, value of the wrong type → `422`.
- `update_settings`: all or nothing. When one key is rejected, `updated` is
  empty and `errors` lists every problem per key.

`PATCH /api/projekt_phases/{projekt_phase_id}/iframe` checks its values the
same way: `url` must be an http(s) URL, `width` and `height` whole numbers,
and `""` clears any of them. A wrong value returns `422` with the problems
per attribute under `error.details`, and nothing is written.

## 2026-07-20

### Poll questions and answers are now paginated

`GET /api/polls/{poll_id}/questions` and
`GET /api/poll_questions/{poll_question_id}/answers` now paginate their
results by default (previously they returned the full list). Each response
gains a `pagination` block with `current_page`, `total_pages`, `total_count`
and `per_page`.

Pass `page` and `per_page` to page through the results. The default page size
is **100**; the first page is returned when `page` is omitted.

```
GET /api/polls/42/questions?page=2&per_page=50
GET /api/poll_questions/17/answers?per_page=25
```

## 2026-06-29

### Projekt list — faster, with pagination, sorting and selective images

The projekt list endpoint (`GET /api/projekts`) is roughly 4x faster on a
plain request (~500–700 ms) and gained three new query options. Combining
pagination with a single image size can make a list request 10–15x faster
than the full unpaginated response.

**Pagination** — pass `page` and/or `per_page` to split results. Supplying
either parameter enables pagination (default page size 20); omit both to
receive every matching projekt in a single response, as before. Paginated
responses include a `pagination` block with `current_page`, `total_pages`,
`total_count` and `per_page`.

```
GET /api/projekts?page=1&per_page=20
```

**Sorting** — order the list with `sort_by` and `sort_direction`.

```
GET /api/projekts?sort_by=name&sort_direction=asc
```

`sort_by` accepts `created_at` (default), `published_at`, `name`,
`page_title`, `order_number`, `total_duration_start` and
`total_duration_end`. `sort_direction` is `asc` (default) or `desc`.
Unrecognized values fall back to the defaults, and sorting combines with
pagination.

**Selective image sizes** — by default every projekt image is returned in
all sizes, and signing each variant URL is the expensive part of the
response. Request only the sizes you need with `image_variant_versions`
(comma-separated):

```
GET /api/projekts?image_variant_versions=600
GET /api/projekts?image_variant_versions=300,600
```

Available widths in px: `150`, `300`, `450`, `600`, `900`, `1200`, `1920`,
plus `original` for the untouched file. Omit the parameter to receive all
sizes.

A typical list view is fastest with pagination and one image size together:

```
GET /api/projekts?page=1&per_page=50&image_variant_versions=600
```

**Monitoring** — request timings (method, path, status, client and total
duration in milliseconds, plus a database-vs-rendering breakdown per entry)
are available to administrators under **API → API request logs** in the
admin area.
