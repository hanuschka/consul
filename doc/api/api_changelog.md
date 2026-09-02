# Changelog

Notable changes to the Consul Projekt API, most recent first.

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
