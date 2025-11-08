# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared/api_client_helper'
require_relative 'shared/api_access_requirements'
require_relative 'schemas/projekts_schemas'
require_relative 'schemas/ideas_schemas'
require_relative 'schemas/comments_proposals_schemas'
require_relative 'schemas/budgets_schemas'
require_relative 'schemas/questions_formulars_schemas'
require_relative 'schemas/deficiency_reports_schemas'
require_relative 'schemas/milestones_livestreams_schemas'
require_relative 'schemas/point_of_interest_schemas'
require_relative 'schemas/miscellaneous_schemas'

Rswag::Specs::SwaggerRoot = Rails.root.join('public').to_s

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1',
        description: <<~DESCRIPTION,
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

          - **Admin**: #{I18n.t('admin.service_users.access_level_admin')}
          - **Public Data**: #{I18n.t('admin.service_users.access_level_public_data')}

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
          - `per_page`: Results per page (default: 100, max: 500)

          ## API Sections

          The API is organized into logical groups:
          - **Projekts**: Core project management
          - **Ideas**: Citizen ideas and proposals
          - **Deficiency Reports**: Issue tracking and reporting

          ## Support

          For issues or questions about the API, please refer to the detailed endpoint documentation below or contact support.
        DESCRIPTION
      },
      paths: {},
      # servers: [
      #   {
      #     url: Rails.application.secrets.swagger_host_url,
      #   }
      # ],
      tags: [
        { name: 'Projekts', description: 'Projekt management and core operations' },
        { name: 'Projekt Phases', description: 'Phases within projekts' },
        { name: 'Proposals', description: 'Proposals for projekt phases' },
        { name: 'Comments', description: 'Comments on projekt phases' },
        { name: 'Polls', description: 'Polls within projekt phases' },
        { name: 'Milestones', description: 'Milestones for projekt phases' },
        { name: 'Budgets', description: 'Budget management for projekt phases' },
        { name: 'Budget Investments', description: 'Budget investment management' },
        { name: 'Arguments', description: 'Arguments for projekt phases' },
        { name: 'Events', description: 'Events associated with projekts' },
        { name: 'Livestreams', description: 'Livestream functionality for projekts' },
        { name: 'Notifications', description: 'Notifications for projekt updates' },
        { name: 'Point Of Interest Categories', description: 'Categories for points of interest in projekts' },
        { name: 'Point Of Interest Pins', description: 'Location pins for projekts' },
        { name: 'Questions', description: 'Questions related to projekt phases' },
        { name: 'Formulars', description: 'Forms associated with projekt phases' },
        { name: 'Texts', description: 'Text content for projekt phases' },
        { name: 'Ideas', description: 'Citizen ideas and proposals' },
        { name: 'Deficiency Reports', description: 'Reports of deficiencies or issues' },
        { name: 'Iframes', description: 'Embedded iframe content' }
      ],
      'x-tagGroups': [
        {
          name: 'Projekts',
          tags: [
            'Projekts',
            'Projekt Phases',
            'Proposals',
            'Polls',
            'Milestones',
            'Budgets',
            'Budget Investments',
            'Comments',
            'Events',
            'Arguments',
            'Livestreams',
            'Notifications',
            'Questions',
            'Formulars',
            'Texts',
            'Iframes',
            'Point Of Interest Categories',
            'Point Of Interest Pins'
          ]
        },
        {
          name: 'Ideas',
          tags: ['Ideas']
        },
        {
          name: 'Deficiency Reports',
          tags: ['Deficiency Reports']
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'Auth Token'
          }
        },
        schemas: Schemas::Projekts.all
                         .merge(Schemas::Ideas.all)
                         .merge(Schemas::CommentsProposals.all)
                         .merge(Schemas::Budgets.all)
                         .merge(Schemas::QuestionsFormulars.all)
                         .merge(Schemas::DeficiencyReports.all)
                         .merge(Schemas::MilestonesLivestreams.all)
                         .merge(Schemas::PointOfInterest.all)
                         .merge(Schemas::Miscellaneous.all)
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml

  config.include ApiClientHelper, type: :request
end
