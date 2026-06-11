# Api documentation

## API endpoint docs

Access API docs by "/api/docs" and "/api/docs_alt" urls.

API Docs are automatically generated from "spec/requests/api" specs by rswag gem.

Regenerate API docs with this rake command:

```bash
  bin/rails api:generate_docs
``` 

It will generate a single file: "public/api_docs/v1/swagger.yaml".
This is an OpenAPI yaml file, which contains machine readable API information.


Every time any specs inside "spec/requests/api"  or "spec/schemas" are changed, API docs have to be manually regenerated with rake command.

You can run api tests which used for generatin docs, to ensure they valid with:

```bash
  bundle exec rspec spec/requests/api
``` 


## Auth

You can create api client on admin page: `/admin/api_clients`

Or reate api client from rails console:
```ruby 
  ApiClient.create(
      name: "Name of api client", 
      service_user_email: "Email of api client"
      # Can be "admin" or "public_data"
      access_level: "admin"
  )
```

service_user_email of api client will be used for creating service api user.

In order to authentificate with api client provide Authorization header with value
```
Authorization: Bearer auth_token
```
A token is generated automatically for each ApiClient.
It can be obtained with ApiClient#access_token. 
