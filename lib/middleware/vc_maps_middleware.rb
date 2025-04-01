class VcMapsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)

    if req.path.match?(%r{/datasource-data/})
      new_path = req.path.sub(%r{.*?/datasource-data/}, "/datasource-data/")
      Rails.logger.info "Redirecting to https://siegburg.virtualcitymap.de#{new_path}"
      return [302, { "Location" => "https://siegburg.virtualcitymap.de#{new_path}" }, []]
    end

    @app.call(env)
  end
end
