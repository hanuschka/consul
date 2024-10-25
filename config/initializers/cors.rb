# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins *(Rails.application.secrets.cors_origins.presence || [])
#     resource '*', headers: :any, methods: [:get, :post, :patch, :put]
#   end
# end
