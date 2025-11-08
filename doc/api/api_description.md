
          # Consul Projekt API

          The Consul Projekt API provides programmatic access to manage participatory budgeting and citizen engagement projects. This API enables you to create and manage various project phases, collect citizen input through proposals, polls, and surveys, and track project progress.

          ## Authentication

          This API uses **Bearer Token (Auth Token)** authentication. All requests require an API client with a valid authentication token.

          ### Creating an API Client

          First, create an API client in your Rails console:

          ```ruby
          ApiClient.create(
            name: "Name of api client",
            service_user_email: "email@example.com",
            access_level: "admin"  # Can be "admin" or "public_data"
          )
          ```

          The `service_user_email` is used to create a service user for the API client.

          ### Authentication Header

          Include your API client's authentication token in the `Authorization` header:

          ```
          Authorization: Bearer YOUR_AUTH_TOKEN
          ```

          The auth token is automatically generated for each API client and can be obtained via:

          ```ruby
          api_client.auth_token
          ```

          ### Access Levels

          - **Admin**: Full access to create, read, update, and delete resources
          - **Public Data**: Read-only access to public data

          #### HTTP Method Requirements

          - **GET**: Available to both `admin` and `public_data` access levels
          - **POST (Create)**: Requires `admin` access level
          - **PATCH (Update)**: Requires `admin` access level
          - **DELETE**: Requires `admin` access level

          Requests with `public_data` access level attempting to use POST, PATCH, or DELETE will receive a `403 Forbidden` error.

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
          - `swagger/v1/swagger.yaml` - OpenAPI specification in YAML format
          - `public/openapi.yaml` - Public OpenAPI specification

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
          ```json
          {
            "error": {
              "type": "forbidden",
              "messages": ["Access denied"]
            }
          }
          ```

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

          For issues or questions about the API, please refer to the detailed endpoint documentation below or contact support.
