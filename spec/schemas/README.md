# API Schemas

This directory contains OpenAPI/Swagger schema definitions for the API documentation.

## Purpose

Schemas are extracted from `swagger_helper.rb` to improve:
- **Organization**: Keep schema definitions separate from configuration
- **Maintainability**: Easier to find and update specific schemas
- **Reusability**: Schemas can be referenced across multiple spec files
- **Readability**: Smaller, focused files instead of one large config file

## File Structure

```
spec_api/schemas/
├── README.md              # This file
└── projekts_schemas.rb    # Schemas for Projekts API
```

## Adding New Schemas

### 1. Create a new schema file

```ruby
# spec_api/schemas/my_resource_schemas.rb
# frozen_string_literal: true

module Schemas
  module MyResource
    MY_RESOURCE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        name: { type: :string, example: 'Sample Resource' },
        created_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' },
        # Add more properties...
      },
      required: %w[id name created_at]
    }.freeze

    # Add more schemas as needed...

    def self.all
      {
        MyResource: MY_RESOURCE_SCHEMA
      }
    end
  end
end
```

### 2. Require the schema file in swagger_helper.rb

```ruby
# spec_api/swagger_helper.rb
require_relative 'schemas/projekts_schemas'
require_relative 'schemas/my_resource_schemas'  # Add this line
```

### 3. Add schemas to the components

```ruby
# In swagger_helper.rb
components: {
  securitySchemes: {
    bearer_auth: { ... }
  },
  schemas: Schemas::Projekts.all
    .merge(Schemas::MyResource.all)  # Add this line
}
```

## Schema Guidelines

### Data Types

Use appropriate OpenAPI types:
- `integer` - Whole numbers
- `string` - Text, dates (with `format: :datetime`)
- `boolean` - true/false values
- `array` - Lists of items
- `object` - Nested objects
- `[:boolean, :string]` - Multiple types (when API might return either)

### Nullable Fields

For fields that can be `null`, add `nullable: true`:

```ruby
parent_id: { type: :integer, nullable: true, example: nil }
```

### Examples

Always provide realistic example values:

```ruby
name: { type: :string, example: 'Sample Project' }
created_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' }
```

### References

Use `$ref` to reference other schemas:

```ruby
projekt_phases: {
  type: :array,
  items: { '$ref' => '#/components/schemas/ProjektPhase' }
}
```

### Required Fields

Specify required fields at the schema level:

```ruby
required: %w[id name created_at updated_at]
```

## Common Patterns

### Boolean Fields That Might Be Strings

Some APIs return booleans as strings (`"true"`/`"false"`). Use multiple types:

```ruby
geozone_affiliated: { type: [:boolean, :string], example: false }
```

### Nested Objects

```ruby
site_customization_page: {
  type: :object,
  properties: {
    title: { type: :string, nullable: true, example: 'Page Title' },
    slug: { type: :string, nullable: true, example: 'page-slug' }
  }
}
```

### Arrays with Object Items

```ruby
projekt_settings: {
  type: :array,
  items: {
    type: :object,
    properties: {
      key: { type: :string, example: 'show_map' },
      value: { type: :string, nullable: true, example: 'true' }
    }
  },
  example: [
    { key: 'show_map', value: 'true' },
    { key: 'enable_comments', value: 'false' }
  ]
}
```

## Testing Schema Changes

After modifying schemas, regenerate the Swagger documentation:

```bash
bundle exec rake rswag:specs:swaggerize
```

Then run your specs to ensure they still pass:

```bash
bundle exec rspec spec_api/
```

## Troubleshooting

### Schema Mismatch Errors

If you get "Expected response body to match schema" errors:

1. Check the actual API response by adding debugging:
   ```ruby
   run_test! do |response|
     puts JSON.pretty_generate(JSON.parse(response.body))
   end
   ```

2. Update the schema to match the actual response
3. Consider using flexible types (`[:boolean, :string]`) for fields that vary
4. Add `nullable: true` for fields that can be null

### Schema Not Found

If you get "Could not resolve schema" errors:
- Ensure the schema file is required in `swagger_helper.rb`
- Verify the schema is included in the `schemas:` hash
- Check that the schema name matches exactly (case-sensitive)

## Best Practices

1. **Freeze constants**: Use `.freeze` to prevent accidental modifications
2. **Organize by resource**: One file per major API resource
3. **Document complex schemas**: Add comments for non-obvious schema structures
4. **Keep examples realistic**: Use example data that resembles production data
5. **Update both schema and specs**: When API changes, update both the schema definition and the spec tests

## Resources

- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [RSwag Documentation](https://github.com/rswag/rswag)
- [JSON Schema Validation](https://json-schema.org/)

