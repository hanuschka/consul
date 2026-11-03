Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Dt.url.present?
      origins [Dt.url]
    end

    resource '*', headers: :any, methods: [:get, :post, :patch, :put, :options], credentials: true
  end

  allow do
    origins { |source, _env| Array(Rails.application.secrets.cors_allowed_origins).include?(source) }

    resource '/api/*', headers: :any, methods: :any
  end
end
