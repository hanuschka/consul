# RSwag Setup Instructions

## 404 error for `/api-docs/v1/swagger.yaml

You're getting a 404 error for `/api-docs/v1/swagger.yaml` because the Swagger documentation file hasn't been generated yet.

## Solution

### 1. Generate the Swagger Documentation

Run this command in your terminal:

```bash
bundle exec rake rswag:specs:swaggerize
```

This will:
- Read all the spec files in `spec_api/`
- Generate `swagger/v1/swagger.yaml` based on the specs
- Make the documentation available at `/api-docs`

### 2. Restart Your Rails Server

After generating the documentation, restart your Rails server:

```bash
# Stop your current server (Ctrl+C)
# Then start it again
bundle exec rails s
```

### 3. View the Documentation

Once the server is running, visit:

```
http://localhost:3000/api-docs
```

You should see the interactive Swagger UI with all your API endpoints documented.

## Verify Everything is Working

1. Check that the swagger directory was created:
   ```bash
   ls -la swagger/v1/swagger.yaml
   ```

2. Run the specs to ensure they pass:
   ```bash
   bundle exec rspec spec_api/projekts_spec.rb
   ```

3. If the specs pass, regenerate the documentation:
   ```bash
   bundle exec rake rswag:specs:swaggerize
   ```

## Troubleshooting

### Swagger file not found
- Make sure you ran `rake rswag:specs:swaggerize`
- Check that `swagger/v1/swagger.yaml` exists
- Verify the path in `config/initializers/rswag_api.rb` matches

### Specs failing
- Ensure your database is set up: `bundle exec rake db:setup`
- Ensure test data exists (you may need factories or seeds)
- Check that the API endpoints exist and work correctly

### UI not loading
- Clear your browser cache
- Check browser console for errors
- Verify the engines are mounted in `config/routes.rb`:
  ```ruby
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  ```

## What the Specs Do

The `projekts_spec.rb` file:
1. Tests your API endpoints
2. Generates OpenAPI documentation
3. Validates request/response schemas
4. Provides examples for API consumers

Every time you update the specs, re-run `rake rswag:specs:swaggerize` to update the documentation.

