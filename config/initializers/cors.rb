Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Dt.url.present?
      origins [Dt.url]
    end

    resource '*', headers: :any, methods: [:get, :post, :patch, :put, :options], credentials: true
  end
end
