# RSwag Spec Troubleshooting Guide

## Common Errors and Solutions

### Error: Expected response code '401' to match '200'

**Error Message:**
```
Rswag::Specs::UnexpectedResponse:
  Expected response code '401' to match '200'
  Response body: {"error":{"type":"unauthorized","messages":"Invalid or missing API token."}}
```

**Cause:** The Authorization header is not being sent with the request, or the API client isn't set up correctly.

**Solutions:**

#### 1. Add `security [bearer_auth: []]` to your endpoint

Make sure ALL endpoints that require authentication have this line:

```ruby
get 'List resources' do
  tags 'Resources'
  produces 'application/json'
  security [bearer_auth: []]  # <-- Add this line!
  
  response '200', 'success' do
    run_test!
  end
end
```

#### 2. Use `let!` instead of `let` for api_client

Change from:
```ruby
let(:api_client) { ApiClient.create!(...) }  # ✗ Lazy evaluation
```

To:
```ruby
let!(:api_client) { ApiClient.create!(...) }  # ✓ Eager evaluation
```

The `!` ensures the client is created BEFORE the test runs.

#### 3. Verify the database is set up

Run these commands:

```bash
# Set up the test database
RAILS_ENV=test bundle exec rake db:create db:migrate

# Or reset if it exists
RAILS_ENV=test bundle exec rake db:reset
```

#### 4. Check that ApiClient table exists

```bash
# Check migrations
bundle exec rails db:migrate:status

# Look for api_clients table
bundle exec rails console
> ApiClient.table_exists?
# Should return true
```

#### 5. Verify bearer_auth is defined in swagger_helper.rb

Check that `swagger_helper.rb` has this in the `components` section:

```ruby
components: {
  securitySchemes: {
    bearer_auth: {
      type: :http,
      scheme: :bearer,
      bearerFormat: 'JWT'
    }
  }
}
```

---

### Error: Missing parameter 'projekt' (or other parameter name)

**Error Message:**
```
Rswag::Specs::MissingParameterError:
  Missing parameter 'projekt'
  
  Please check your spec. It looks like you defined a body parameter,
  but did not declare usage via let. Try adding:
  
      let(:projekt) {}
```

**Cause:** You defined a body parameter in the spec but didn't provide a `let` statement with example data.

**Solutions:**

1. Add a `let` block with example request data:
   ```ruby
   response '201', 'resource created' do
     let(:projekt) do
       {
         projekt: {
           name: 'Test Projekt'
         }
       }
     end
     
     run_test!
   end
   ```

2. For endpoints that need an existing record (PATCH, PUT, DELETE), also provide the `id`:
   ```ruby
   response '200', 'resource updated' do
     let(:test_projekt) { Projekt.create!(name: 'Original') }
     let(:id) { test_projekt.id }
     let(:projekt) do
       {
         projekt: {
           name: 'Updated'
         }
       }
     end
     
     run_test!
   end
   ```

---

### Error: Expected response body to match schema

**Error Message:**
```
Rswag::Specs::UnexpectedResponse:
  Expected response body to match schema: [errors]
  Response body: {...}
```

**Cause:** The API response doesn't match the schema you defined in your spec.

**Solutions:**

1. **Check the actual response structure**: Add debugging to see what's returned:
   ```ruby
   response '201', 'created' do
     run_test! do |response|
       puts "Response: #{JSON.pretty_generate(JSON.parse(response.body))}"
     end
   end
   ```

2. **Update your schema** to match the actual response

3. **Provide required data**: Make sure your test data includes all required fields:
   ```ruby
   let(:projekt) do
     {
       projekt: {
         name: 'Test Projekt',
         geozone_affiliated: false,
         show_start_date_in_frontend: true,
         show_end_date_in_frontend: true
       }
     }
   end
   ```

4. **Check for validation errors**: The API might be rejecting your test data

---

### Error: ActiveRecord::RecordInvalid: Validation failed

**Cause:** The ApiClient can't be created due to validation errors.

**Solutions:**

1. Check the ApiClient model for required fields
2. Make sure you're passing all required attributes:
   ```ruby
   let!(:api_client) do
     ApiClient.create!(
       name: 'Test Client',
       registration_status: :registered
     )
   end
   ```

---

### Error: uninitialized constant ApiClient

**Cause:** The ApiClient model isn't loaded or doesn't exist.

**Solutions:**

1. Make sure you're running from the Rails environment:
   ```bash
   bundle exec rspec spec_api/my_spec.rb
   ```

2. Check that the model file exists:
   ```bash
   ls app/models/*/api_client.rb
   ```

3. Verify it's required in spec_helper:
   ```ruby
   # spec_api/spec_helper.rb should load Rails
   require 'rails_helper'  # or similar
   ```

---

### Error: Connection refused / Database error

**Cause:** Test database isn't running or configured.

**Solutions:**

1. Check `config/database.yml` has a test section
2. Make sure PostgreSQL (or your DB) is running:
   ```bash
   # For PostgreSQL
   brew services start postgresql
   # or
   pg_ctl -D /usr/local/var/postgres start
   ```

3. Create the test database:
   ```bash
   RAILS_ENV=test bundle exec rake db:create
   ```

---

### Error: Schema not found / Table doesn't exist

**Cause:** Migrations haven't been run in test environment.

**Solutions:**

```bash
# Run all migrations
RAILS_ENV=test bundle exec rake db:migrate

# Or reset everything
RAILS_ENV=test bundle exec rake db:drop db:create db:migrate
```

---

### Error: 404 Not Found for API endpoint

**Cause:** The route doesn't exist or the controller isn't set up.

**Solutions:**

1. Check routes:
   ```bash
   bundle exec rails routes | grep projekts
   ```

2. Verify the controller exists:
   ```bash
   ls app/controllers/*/api/*_controller.rb
   ```

3. Make sure the controller is properly namespaced:
   ```ruby
   class Api::ProjektsController < Api::BaseController
     # ...
   end
   ```

---

### Tests pass but Swagger UI shows wrong examples

**Cause:** Swagger documentation is outdated.

**Solution:**

Regenerate the Swagger docs:
```bash
bundle exec rake rswag:specs:swaggerize
```

---

### Error: Missing parameter 'projekt'

**Error Message:**
```
Rswag::Specs::MissingParameterError:
Missing parameter 'projekt'

Please check your spec. It looks like you defined a body parameter,
but did not declare usage via let. Try adding:
let(:projekt) {}
```

**Cause:** RSwag expects body parameters to be defined using `let` blocks, and they must be placed **before** the `schema` definition in each response block.

**Solution:** Define `let` blocks **before** the schema in each response.

**✅ CORRECT ORDER:**
```ruby
response '201', 'projekt created' do
  # 1. First: let blocks (parameter values)
  let(:projekt) do
    {
      projekt: {
        name: 'Test Projekt',
        geozone_affiliated: false,
        show_start_date_in_frontend: true,
        show_end_date_in_frontend: true
      }
    }
  end
  
  # 2. Then: schema definition
  schema type: :object,
         properties: {
           data: {
             type: :object,
             properties: {
               projekt: { '$ref' => '#/components/schemas/Projekt' }
             }
           }
         }
  
  # 3. Finally: run_test!
  run_test!
end
```

**❌ INCORRECT ORDER:**
```ruby
response '201', 'projekt created' do
  schema type: :object, properties: { ... }  # Schema BEFORE let - WRONG!
  
  let(:projekt) do  # This comes too late!
    { projekt: { name: 'Test' } }
  end
  
  run_test!
end
```

**Key Points:**
- Each response (201, 422, etc.) needs its own `let` block with appropriate data
- Order matters: `let` → `before` → `schema` → `run_test!`
- Different responses need different data (valid for 201, invalid for 422)

---

### Error: Expected response body to match schema

**Error Message:**
```
Rswag::Specs::UnexpectedResponse:
Expected response body to match schema: The property '#/data/projekt/geozone_affiliated' of type string did not match the following type: boolean
The property '#/data/projekt/projekt_settings/18/value' of type null did not match the following type: string
```

**Cause:** The actual API response doesn't match the schema defined in `swagger_helper.rb`. Common issues:
- Fields returning as strings when schema expects boolean (or vice versa)
- Fields returning null when schema doesn't allow nullable
- Fields missing from response that are marked as required

**Solutions:**

**1. Make fields nullable if they can be null:**
```ruby
# In swagger_helper.rb
value: { type: :string, nullable: true, example: 'true' }
```

**2. Allow multiple types for flexible fields (booleans that might be strings):**
```ruby
# In swagger_helper.rb
geozone_affiliated: { type: [:boolean, :string], example: false }
show_start_date_in_frontend: { type: [:boolean, :string], example: true }
```

**3. Check the actual API response:**
Add debugging to see what's actually being returned:
```ruby
response '201', 'projekt created' do
  let(:projekt) { { projekt: { name: 'Test' } } }
  
  run_test! do |response|
    puts "Actual response:"
    puts JSON.pretty_generate(JSON.parse(response.body))
  end
end
```

**4. Common field type issues:**

| Schema Type | Actual Value | Fix |
|------------|--------------|-----|
| `boolean` | `"true"` or `"false"` | Use `type: [:boolean, :string]` |
| `boolean` or `string` | `null` | Add `nullable: true` to the field |
| `string` | `null` | Add `nullable: true` |
| `integer` | `null` | Add `nullable: true` |
| `integer` | `"123"` | Use `type: [:integer, :string]` or fix serializer |
| Required field | Missing from response | Remove from `required` array or fix controller |

**Note:** Even if a field accepts multiple types like `type: [:boolean, :string]`, it still needs `nullable: true` if it can be `null`.

**5. Update swagger docs after schema changes:**
```bash
bundle exec rake rswag:specs:swaggerize
```

---

### Error: Expected response code '200' to match '422' (or other error code)

**Error Message:**
```
Rswag::Specs::UnexpectedResponse:
Expected response code '200' to match '422'
Response body: {"message":"Projekt destroyed"}
```

**Cause:** The test expects an error response (422, 404, etc.) but the API operation succeeds instead. This happens when testing error cases without setting up the conditions that would actually trigger the error.

**Examples:**
- Testing DELETE 422 but the record deletes successfully
- Testing UPDATE 422 but the update succeeds
- Testing POST 422 with valid data

**Solutions:**

**1. For validation errors (422), use invalid data:**
```ruby
response '422', 'invalid request' do
  let(:projekt) do
    {
      projekt: {
        name: ''  # Invalid - will fail validation
      }
    }
  end
  
  run_test!
end
```

**2. For DELETE failures, mock the destroy method:**
```ruby
response '422', 'unable to delete projekt' do
  let(:test_projekt) { Projekt.create!(name: 'Test') }
  let(:id) { test_projekt.id }
  
  # Mock destroy to return false with errors mock
  before do
    # Create a null object mock that accepts any method call
    errors_mock = double('errors').as_null_object
    allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete record'] })
    
    allow_any_instance_of(Projekt).to receive(:destroy).and_return(false)
    allow_any_instance_of(Projekt).to receive(:errors).and_return(errors_mock)
  end
  
  run_test!
end
```

**Note:** Using `.as_null_object` creates a mock that accepts any method call Rails might make internally, preventing "unexpected message" errors.

**3. For 404 errors, use non-existent IDs:**
```ruby
response '404', 'projekt not found' do
  let(:id) { 999999 }  # ID that doesn't exist
  run_test!
end
```

**4. For permission errors (403), test without proper authentication:**
```ruby
response '403', 'forbidden' do
  let(:Authorization) { "Bearer invalid_token" }
  run_test!
end
```

**5. For update failures that require existing records:**
```ruby
response '422', 'invalid request' do
  let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
  let(:id) { test_projekt.id }
  let(:setting) do
    {
      setting: {
        key: 'existing_setting',
        value: 'invalid_value'
      }
    }
  end

  # Create the record first, then mock update to fail
  before do
    test_projekt.projekt_settings.create!(key: 'existing_setting', value: 'old_value')
    
    # Mock the update to fail validation
    allow_any_instance_of(ProjektSetting).to receive(:update).and_return(false)
    
    # Create errors mock
    errors_mock = double('errors').as_null_object
    allow(errors_mock).to receive(:full_messages).and_return(['Value is invalid'])
    allow_any_instance_of(ProjektSetting).to receive(:errors).and_return(errors_mock)
  end
  
  run_test!
end
```

**Key Point:** Always set up the actual conditions that would trigger the error in a real scenario. Don't just hope for an error - create the conditions that cause it!

**Common Pitfall:** If your API finds a record by ID or key before updating it, make sure that record exists first. Otherwise, you'll get a 404 instead of a 422.

---

## Debugging Tips

### 1. Run a Single Test

```bash
# Run just one spec file
bundle exec rspec spec_api/projekts_spec.rb

# Run with verbose output
bundle exec rspec spec_api/projekts_spec.rb --format documentation

# Run a specific line
bundle exec rspec spec_api/projekts_spec.rb:22
```

### 2. Add Debugging Output

```ruby
response '200', 'success' do
  # Add debugging
  before do
    puts "API Client: #{api_client.inspect}"
    puts "Auth Token: #{api_client.auth_token}"
    puts "Authorization Header: #{Authorization}"
  end
  
  run_test!
end
```

### 3. Check What's Being Sent

```ruby
response '200', 'success' do
  run_test! do |response|
    puts "Status: #{response.status}"
    puts "Body: #{response.body}"
    puts "Headers: #{response.headers}"
  end
end
```

### 4. Test in Rails Console

```ruby
# Test API client creation
rails console
> client = ApiClient.create!(name: 'Test', registration_status: :registered)
> client.auth_token
# Should return a token string
```

### 5. Test API Manually with curl

```bash
# Get a token from console first
rails console
> ApiClient.create!(name: 'Test', registration_status: :registered).auth_token

# Then test with curl
curl -H "Authorization: Bearer YOUR_TOKEN_HERE" \
     http://localhost:3000/api/projekts
```

---

## Prevention Checklist

Before writing new specs, verify:

- [ ] Database is set up (`RAILS_ENV=test rake db:migrate`)
- [ ] ApiClient model exists and has `has_secure_token :auth_token`
- [ ] `bearer_auth` is defined in `swagger_helper.rb`
- [ ] All authenticated endpoints have `security [bearer_auth: []]`
- [ ] Using `let!(:api_client)` with the `!` for eager loading
- [ ] Controller inherits from `Api::BaseController` and has authentication

---

## Still Having Issues?

1. Check the `SETUP.md` file for initial setup instructions
2. Read the `AUTHENTICATION_GUIDE.md` for authentication details
3. Look at `projekts_spec.rb` as a working example
4. Use `TEMPLATE.rb` as a starting point for new specs

If all else fails, try:
```bash
# Nuclear option - reset everything
RAILS_ENV=test bundle exec rake db:drop db:create db:migrate
bundle exec rspec spec_api/
bundle exec rake rswag:specs:swaggerize
```

