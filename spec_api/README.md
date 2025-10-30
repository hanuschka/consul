# API Specs with RSwag

This directory contains RSwag (RSpec + Swagger) specifications for the API endpoints.

## Overview

RSwag is a tool that combines RSpec integration tests with OpenAPI (Swagger) documentation generation. Each spec file tests the API endpoints while simultaneously generating OpenAPI documentation.

## Setup

Make sure you have the rswag gem installed in your Gemfile:

```ruby
gem 'rswag'
```

## Running the Specs

To run the API specs:

```bash
# Run all API specs
bundle exec rspec spec_api

# Run a specific spec file
bundle exec rspec spec_api/projekts_spec.rb
```

## Generating Swagger Documentation

**IMPORTANT:** You must generate the Swagger documentation before you can view it in the browser!

After writing or updating specs, generate the Swagger/OpenAPI documentation:

```bash
bundle exec rake rswag:specs:swaggerize
```

This will generate the swagger YAML file at `swagger/v1/swagger.yaml`.

### If you see "Not Found /api-docs/v1/swagger.yaml"

This means the documentation hasn't been generated yet. Run the command above, then restart your Rails server.

## Viewing the Documentation

If you have rswag-ui set up (see installation instructions below), you can view the interactive API documentation by:

1. Starting your Rails server
2. Navigating to `/api-docs` in your browser

## Installation of rswag-ui (Optional)

To enable the interactive Swagger UI, add to your Gemfile:

```ruby
gem 'rswag-ui'
```

Then mount the engine in your `config/routes.rb`:

```ruby
mount Rswag::Ui::Engine => '/api-docs'
mount Rswag::Api::Engine => '/api-docs'
```

## Directory Structure

```
spec_api/
├── README.md                    # This file - main documentation
├── SETUP.md                     # Setup and troubleshooting guide
├── AUTHENTICATION_GUIDE.md      # Detailed authentication setup
├── TROUBLESHOOTING.md           # Common errors and solutions
├── TEMPLATE.rb                  # Template for new spec files
├── swagger_helper.rb            # RSwag configuration
├── spec_helper.rb               # RSpec configuration
├── projekts_spec.rb             # Example spec file
└── schemas/
    ├── README.md                # Schema documentation
    └── projekts_schemas.rb      # Projekt-related schemas
```

### Schemas Directory

OpenAPI schemas are organized in the `schemas/` directory for better maintainability:

- **Location**: `spec_api/schemas/`
- **Purpose**: Define reusable schema definitions for API responses
- **Benefits**: 
  - Keeps `swagger_helper.rb` clean and focused on configuration
  - Makes schemas easier to find and update
  - Allows organizing schemas by resource/domain
- **Documentation**: See `schemas/README.md` for how to add new schemas

**Example:**
```ruby
# spec_api/schemas/projekts_schemas.rb
module Schemas
  module Projekts
    PROJEKT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        name: { type: :string, example: 'Sample Projekt' },
        # ... more properties
      },
      required: %w[id name created_at updated_at]
    }.freeze

    def self.all
      {
        Projekt: PROJEKT_SCHEMA,
        ProjektPhase: PROJEKT_PHASE_SCHEMA,
        ContentBlock: CONTENT_BLOCK_SCHEMA
      }
    end
  end
end
```

## Writing New Specs

When creating new API specs:

1. **Use the Template**: Copy `spec_api/TEMPLATE.rb` as a starting point
   ```bash
   cp spec_api/TEMPLATE.rb spec_api/my_resource_spec.rb
   ```

2. Require `swagger_helper` at the top
3. Set up authentication using one of the methods described above
4. Use the rswag DSL to define paths, parameters, and responses
5. Define reusable schemas in `spec_api/schemas/` directory (see `schemas/README.md` for details)

### Quick Example Structure

```ruby
require_relative './swagger_helper'

RSpec.describe 'Resource API', type: :request do
  # Authentication
  let(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }
  
  path '/api/resources' do
    get 'List resources' do
      tags 'Resources'
      produces 'application/json'
      
      response '200', 'resources found' do
        schema type: :object,
               properties: {
                 data: { type: :array }
               }
        
        run_test!
      end
    end
  end
end
```

See `spec_api/TEMPLATE.rb` for a complete example with all CRUD operations.

## Authentication

The Projekts API uses bearer token authentication. There are two ways to set this up in your specs:

### Option 1: Direct Setup (Currently Used)

Create an `ApiClient` directly in your test setup:

```ruby
RSpec.describe 'My API', type: :request do
  let(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }
  
  # Your specs here...
end
```

### Option 2: Use Shared Context

Alternatively, use the shared context defined in `spec_helper.rb`:

```ruby
RSpec.describe 'My API', type: :request do
  include_context 'api_authenticated'
  
  # This automatically provides:
  # - api_client
  # - Authorization header
  
  # Your specs here...
end
```

The `Authorization` header will be automatically included in requests that specify `security [bearer_auth: []]`.

## Current Specs

- **projekts_spec.rb** - Projekts CRUD operations and settings management

## Resources

- [RSwag Documentation](https://github.com/rswag/rswag)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)

