# Consul API Documentation

Programmatic REST access for managing projekts, proposals, comments, polls,
deficiency reports, points of interest and more.

## Contents

- [Endpoint reference (OpenAPI)](#endpoint-reference-openapi)
- [Authentication](#authentication)
- [Which user authors content created via the API?](#which-user-authors-content-created-via-the-api)
- [The system user](#the-system-user)
- [The service user (dedicated API user)](#the-service-user-dedicated-api-user)
- [Managing API clients in the admin area](#managing-api-clients-in-the-admin-area)
- [Creating API clients from the Rails console](#creating-api-clients-from-the-rails-console)

---

## Endpoint reference (OpenAPI)

The full, machine-readable endpoint reference is served from the running
application:

- `/api/docs` — interactive OpenAPI documentation
- `/api/docs_alt` — alternative documentation view

The reference is generated from the request specs under `spec/requests/api`
(and schemas under `spec/schemas`) by the rswag gem. After changing any of
those specs, regenerate the docs:

```bash
bin/rails api:generate_docs
```

This writes `public/api_docs/v1/swagger.yaml` (the OpenAPI specification). Do
not edit that file by hand — always regenerate it.

---

## Authentication

The API uses **Bearer token** authentication. **Every** request — including
read-only `GET` requests — must carry a valid token. A missing or unknown
token returns `401 Unauthorized` before anything else is evaluated; there is
no anonymous access.

Send the token in the `Authorization` header:

```
Authorization: Bearer sk_your_token_here
```

Each API client receives its own token, generated automatically on creation
(prefixed with `sk_`). A token can be rotated at any time — see
[Managing API clients](#managing-api-clients-in-the-admin-area).

### Access levels

An API client has one of two access levels, which control what the token may
do once it is recognised:

| Access level  | `GET` (read) | `POST` / `PATCH` / `DELETE` (write) |
|---------------|:------------:|:-----------------------------------:|
| `public_data` | ✅           | ❌ → `403 Forbidden`                |
| `admin`       | ✅           | ✅                                  |

Use `admin` only when the client genuinely needs to create, update or delete
content. For read-only integrations, prefer `public_data`.

---

## Which user authors content created via the API?

Every resource created through the API — a proposal, comment, idea,
deficiency report, point of interest, etc. — is stored with an **author**,
exactly as if a logged-in person had created it. The API client never writes
content "anonymously": it always acts on behalf of a real `User` record.

Which user that is depends on a single per-client setting, **"Use system
user"**:

| "Use system user" | Author of created content                            |
|-------------------|------------------------------------------------------|
| **On** (default)  | The shared **system user**                           |
| **Off**           | A **dedicated service user** belonging to the client |

In code this is the client's `content_author`:

- **System-user mode** (the default for new clients) → content is authored by
  the single shared system user. Use this when you don't need API content to
  be visibly attributable to a distinct account — it keeps things simple and
  needs no extra setup.
- **Dedicated-user mode** → content is authored by a service user created
  specifically for that client, with its own name and avatar. Use this when
  API-created content should appear under its own recognisable identity (e.g.
  "Website frontend" or "Mobile app").

> **Fallback safety net:** if a client is set to dedicated-user mode but its
> service user has not been created yet, content falls back to the system
> user rather than failing. Always confirm the service user exists (the admin
> form creates it for you) before relying on the dedicated identity.

The two author types are described in detail below.

---

## The system user

The system user is a **single, shared account** that represents "the
platform / the administration" as a content author. There is exactly one per
installation — a database constraint guarantees it cannot be duplicated.

**It is created automatically.** You never create it by hand: the first time
the application needs it, it is provisioned on demand with sensible defaults:

- Display name taken from the organisation name setting (`org_name`), falling
  back to `"System"`.
- Avatar set to the site logo, if one is configured.
- A randomised, unusable password — the system user is **not** a login
  account.

If your installation previously used the legacy `masterportal` author account,
that account is transparently upgraded into the system user the first time it
is needed, so existing content keeps its author.

**Where to customise it:** in the admin area sidebar, open **Application →
System user**. There you can change the system user's display name and avatar.
This is the identity that will appear next to all content published in
system-user mode (across every client that uses it), so pick a name and image
that read well publicly.

---

## The service user (dedicated API user)

A service user is a **per-client author account**. It exists only to be the
visible author of content created by one specific API client — it is **not**
meant for interactive login (it is created with a random password and should
never be used to sign in directly; use the API token instead).

**How it is created:** when you save an API client with **"Use system user"
turned off** and provide a **service user email**, the service user is created
automatically. From the admin form you can also set:

- Username (auto-generated from the client name, e.g.
  `website_frontend_service`, if you leave it blank)
- First name / last name
- Avatar
- Background image

The email address must be unique and is used purely to anchor the account; the
service user logs in nowhere.

**Where to manage it:** it is created and edited together with its API client
under **Developer area → API clients** (see below). A client's detail page
shows which user it posts as — either its service user's profile, or a note
that it publishes under the system user.

---

## Managing API clients in the admin area

API clients are managed in the **new admin area**. In the sidebar, open
**Developer area → API clients**. From there you can:

- **See every client** and which user each one posts as.
- **Create a client** — set its name and access level, then choose its author
  identity with the **"Use system user"** switch:
  - Leave the switch **on** to publish as the shared system user (no further
    input needed).
  - Turn it **off** to create a dedicated service user — you then provide the
    service user email and, optionally, its name/avatar/background image.
- **View a client's token**, copy it, and **regenerate** it. Regenerating
  immediately invalidates the previous token, so any integration still using
  the old token will stop working until updated.
- **Edit or delete** a client.

The matching **system user** identity (used by every client in system-user
mode) is edited separately under **Application → System user**, as described
above.

> **A note on the legacy admin.** The older admin area also exposes an API
> clients screen, but its form predates the "Use system user" switch and only
> lets you set name, access level and service user email — it always creates
> dedicated-user clients. Use the new admin area (**Developer area → API
> clients**) so you can choose between system-user and dedicated-user mode.

---

## Creating API clients from the Rails console

The admin UI is the recommended path. If you need to script client creation,
note that **`ApiClient.create` does not build the service user for you** — the
admin form does that as a separate step. Replicate it explicitly:

```ruby
# Publishes as the shared SYSTEM user (the default — use_system_user is true)
ApiClient.create!(
  name: "Mobile app",
  access_level: "admin"          # or "public_data" for read-only
)

# Publishes as a DEDICATED service user
client = ApiClient.create!(
  name: "Website frontend",
  access_level: "admin",
  use_system_user: false,
  service_user_email: "frontend-bot@example.org"
)

# Required for dedicated-user mode: actually create the service user.
# Until this runs, the client falls back to the system user.
ApiClients::CreateServiceUserService.call(
  api_client: client,
  user_attributes: { first_name: "Website", last_name: "Bot" }
)
```

Read or rotate the token:

```ruby
client.access_token            # the current Bearer token
client.regenerate_access_token # issues a new token, invalidates the old one
```

