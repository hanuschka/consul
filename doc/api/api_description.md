
          # Consul Projekt API

          The Consul Projekt API provides programmatic access to manage participatory budgeting and citizen engagement projects. This API enables you to create and manage various project phases, collect citizen input through proposals, polls, and surveys, and track project progress.

          ## Authentication

          This API uses **Bearer Token** authentication. Every request — including read-only `GET` requests — requires an API client with a valid token; a missing or invalid token returns `401 Unauthorized` (see *HTTP Method Requirements* below).

          ### Creating an API Client

          API clients are created by a platform administrator in the admin area,
          under **Developer area → API clients**. Creating a client there also
          issues its token and sets up the user that will author API content
          (see *Content author* below). This is the main way to create a client.

          ### Creating an API Client via the Rails console

          As an alternative to the admin area, clients can also be created from
          the Rails console. Note that it does **not** build the service user
          automatically — that is only done by the admin form or by calling
          `ApiClients::CreateServiceUserService`:

          ```ruby
          # Publishes content as the shared system user (the default)
          ApiClient.create!(
            name: "Mobile app",
            access_level: "admin"  # Can be "admin" or "public_data"
          )
          ```

          ### Content author

          Every resource created via the API is stored with a real author — the
          API never writes content anonymously. Each client decides which user
          that is through its **"Use system user"** setting:

          - **On (default):** content is authored by the single shared **system
            user** that represents the platform. No extra setup is required.
          - **Off:** content is authored by a **dedicated service user** created
            for that client (its `service_user_email` anchors the account). Use
            this when API content should appear under its own distinct identity.

          A service user exists only to be the visible author of API content; it
          cannot be used to log in. The system user's public name and avatar are
          configured in the admin area under **Application → System user**.

          ### Authentication Header

          Include your API client's authentication token in the `Authorization` header:

          ```
          Authorization: Bearer YOUR_AUTH_TOKEN
          ```

          The access token is automatically generated for each API client and can be obtained via:

          ```ruby
          api_client.access_token
          ```

          The token can be rotated with `api_client.regenerate_access_token`.

          ### Access Levels

          - **Admin**: Full access to create, read, update, and delete resources
          - **Public Data**: Read-only access to public data

          #### HTTP Method Requirements

          Every request — including `GET` — must carry a valid `Authorization: Bearer <token>` header. A missing or unrecognized token returns `401 Unauthorized` **before** any access-level check is evaluated (enforced by `authenticate_api_client!`, which runs as a `before_action` on every endpoint). There is no anonymous/public GET access.

          Once a valid token is presented, the client's access level controls what it may do:

          - **GET**: Available to both `admin` and `public_data` access levels
          - **POST (Create)**: Requires `admin` access level
          - **PATCH (Update)**: Requires `admin` access level
          - **DELETE**: Requires `admin` access level

          Requests with `public_data` access level attempting to use POST, PATCH, or DELETE will receive a `403 Forbidden` error.

          #### Authentication vs. authorization errors

          - **`401 Unauthorized`** — *authentication* failure. A missing or invalid Bearer token rejects the request (all methods, including GET) before any read/admin check. Body:
            ```json
            { "error": { "type": "unauthorized", "messages": ["Invalid or missing API token."] } }
            ```
          - **`403 Forbidden`** — *authorization* failure. A **valid** token whose access level is insufficient (e.g. a `public_data` client attempting POST/PATCH/DELETE). Body:
            ```json
            { "error": { "type": "forbidden", "messages": ["You do not have permission to perform this action. Admin access required."] } }
            ```

          ## Key Features

          - **Project Management**: Create and manage projects with multiple phases
          - **Participatory Budgeting**: Implement budget allocation mechanisms
          - **Citizen Engagement**: Collect ideas, proposals, and feedback from participants
          - **Surveys & Forms**: Deploy custom forms to gather structured input
          - **Event & Livestream Support**: Schedule and manage live events and streams
          - **Milestone Tracking**: Track project progress with status updates
          - **Geospatial Features**: Mark points of interest on maps

          ## Getting Started

          ### API Documentation

          API documentation is automatically generated from test specifications using the Rswag gem. The following documentation formats are available:
          - `/api/docs` - Interactive OpenAPI documentation
          - `/api/docs_alt` - Alternative documentation view

          To regenerate API documentation after making changes to specs, run:

          ```bash
          bin/rails api:generate_docs
          ```

          This generates:
          - `public/api_docs/v1/swagger.yaml` - OpenAPI specification in YAML format

          **Note:** Whenever you modify specs in `spec/requests/api` or `spec/schemas`, you must regenerate the API documentation.

          ### Running API Tests

          To verify that your API specifications are valid, run:

          ```bash
          bundle exec rspec spec/requests/api
          ```

          ## Response Format

          All API responses are in JSON format with the following structure:

          **Success Response:**
          ```json
          {
            "data": {
              "resource_name": { ... }
            },
            "pagination": {
              "current_page": 1,
              "total_pages": 10,
              "total_count": 100,
              "per_page": 10
            }
          }
          ```

          **Error Response:**

          All errors share the envelope `{ "error": { "type": ..., "messages": [...] } }`. The API produces these types:

          ```json
          {
            "error": {
              "type": "forbidden",
              "messages": ["You do not have permission to read this resource."]
            }
          }
          ```

          | HTTP status | `type`         | Example message                                     |
          |-------------|----------------|-----------------------------------------------------|
          | 401         | `unauthorized` | `Invalid or missing API token.`                     |
          | 403         | `forbidden`    | `You do not have permission to read this resource.` |
          | 404         | `not_found`    | `Not found`                                          |

          ## Pagination

          List endpoints support pagination using `page` and `per_page` query parameters:
          - `page`: Page number (default: 1)
          - `per_page`: Results per page (default: 500 for most endpoints, 5000 for comments)

          ## API Sections

          The API is organized into logical groups:
          - **Projekts**: Core project management
          - **Ideas**: Citizen ideas and proposals
          - **Deficiency Reports**: Issue tracking and reporting

          ## Support

          Most questions can be answered without waiting on a reply:

          - **Changelog** — check it (in the sidebar) for recent endpoint and parameter changes.
          - **Endpoint reference** — every endpoint below documents its parameters, request body, and example responses.
          - **Error Handling** — the section above maps each status code (`401`, `403`, `404`, …) to its likely cause.

          If you still need help, contact your platform administrator or demokratie.today support. To speed up diagnosis, please include:

          - the request path and HTTP method (e.g. `GET /api/projekts`);
          - the timestamp of the request;
          - the HTTP status code you received; and
          - your API client name.

          Platform administrators can look up any request — with full timing and response details — under **API → API request logs** in the admin area.
