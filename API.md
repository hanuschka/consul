Access API docs by "/api/docs" and "/api/docs_alt" urls.

API Docs are automatically generated from "spec/requests/api" specs by rswag gem.

Regenerate API docs with this rake command:

```bash
  bin/rails api:generate_docs
``` 

It will generate two files "swagger/v1/swagger.yml" 
and "public.openapi.yaml" files.
Those files are OpenAPI yaml files, which contain machine redable API information.


Every time any specs inside "spec/requests/api"  or "spec/schemas" are changed, API docs have to be manually regenerated with rake command.
