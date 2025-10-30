# API Authentication Guide for RSwag Specs

This guide explains how to set up authentication for your API spec files.

## Overview

The API uses bearer token authentication via `ApiClient`. Each request must include an `Authorization` header with a valid token.

## Setup Methods

### Method 1: Direct Setup (Recommended for Individual Specs)

Add this at the top of your spec file:

```ruby
RSpec.describe 'My API', type: :request do
  let(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }
  
  # Your endpoints...
end
```

**Pros:**
- Clear and explicit
- Easy to customize per spec
- No additional includes needed

**Cons:**
- Repeated code across multiple spec files

### Method 2: Shared Context (Recommended for Multiple Specs)

Use the shared context defined in `spec_helper.rb`:

```ruby
RSpec.describe 'My API', type: :request do
  include_context 'api_authenticated'
  
  # Your endpoints...
end
```

**Pros:**
- DRY (Don't Repeat Yourself)
- Centralized authentication logic
- Easy to update globally

**Cons:**
- Less explicit
- Requires familiarity with shared contexts

## How It Works

### 1. ApiClient Model

```ruby
class ApiClient < ApplicationRecord
  has_secure_token :auth_token
  enum registration_status: [:registration_in_progress, :registered]
end
```

- Creates a unique `auth_token` automatically
- Must have `registration_status: :registered` to be valid

### 2. Authorization Header

```ruby
let(:Authorization) { "Bearer #{api_client.auth_token}" }
```

- RSwag automatically sends this header with requests
- The controller extracts the token and validates it

### 3. Controller Authentication

```ruby
class Api::BaseController < ActionController::API
  before_action :authenticate_api_client!
  
  def authenticate_api_client!
    token = request.headers['Authorization']&.split(' ')&.last
    client = ApiClient.find_by(auth_token: token)
    
    if client.present?
      @current_client = client
    else
      render json: { error: { messages: 'Invalid or missing API token.' } }, 
             status: :unauthorized
    end
  end
end
```

## Examples

### Basic GET Request (No Auth Required)

```ruby
path '/api/public_resources' do
  get 'List public resources' do
    tags 'Public'
    produces 'application/json'
    
    response '200', 'success' do
      run_test!
    end
  end
end
```

### Protected POST Request (Auth Required)

```ruby
path '/api/protected_resources' do
  post 'Create a resource' do
    tags 'Protected'
    consumes 'application/json'
    produces 'application/json'
    security [bearer_auth: []]  # <-- This requires authentication
    
    parameter name: :resource, in: :body, schema: {
      type: :object,
      properties: {
        resource: {
          type: :object,
          properties: {
            name: { type: :string }
          }
        }
      }
    }
    
    response '201', 'created' do
      let(:resource) { { resource: { name: 'Test' } } }
      run_test!
    end
    
    response '401', 'unauthorized' do
      let(:Authorization) { 'Bearer invalid_token' }
      run_test!
    end
  end
end
```

### Testing Different Auth States

```ruby
RSpec.describe 'My API', type: :request do
  # Default: Valid authentication
  let(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }
  
  path '/api/resources' do
    get 'List resources' do
      tags 'Resources'
      produces 'application/json'
      
      response '200', 'authenticated request succeeds' do
        run_test!
      end
      
      response '401', 'unauthenticated request fails' do
        # Override the Authorization for this specific test
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end
end
```

## Troubleshooting

### Error: "ApiClient not found"

**Problem:** The model hasn't been loaded or doesn't exist.

**Solution:** Make sure you're running specs from the Rails environment:
```bash
bundle exec rspec spec_api/my_spec.rb
```

### Error: "Invalid or missing API token"

**Problem:** The token isn't being sent correctly.

**Solution:** 
1. Check that you've defined `let(:Authorization)`
2. Ensure endpoints that need auth have `security [bearer_auth: []]`
3. Verify the ApiClient was created with `registration_status: :registered`

### Error: "Unauthorized" in tests

**Problem:** The auth token might not be persisting between requests.

**Solution:** Make sure you're using `let` (not `let!`) so the client is created lazily:
```ruby
let(:api_client) { ApiClient.create!(...) }  # ✓ Good
let!(:api_client) { ApiClient.create!(...) } # ✗ Might cause issues
```

## Best Practices

1. **Use consistent naming**: Always call your client `api_client` for clarity
2. **Set registration_status**: Always create clients with `registration_status: :registered`
3. **Test auth failures**: Include 401 responses in your specs
4. **Clean up**: Use transactional fixtures to automatically clean up test data
5. **Document security**: Always add `security [bearer_auth: []]` to protected endpoints

## Complete Working Example

See `spec_api/projekts_spec.rb` for a complete, working example of authentication in action.

See `spec_api/TEMPLATE.rb` for a template you can copy and modify.

