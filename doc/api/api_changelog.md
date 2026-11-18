# Changelog

Notable changes to the Consul Projekt API, most recent first.

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
