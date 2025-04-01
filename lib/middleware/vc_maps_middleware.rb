class VcMapsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)

    if req.path.start_with?("/datasource-data")
      Rails.logger.info "Proxying to https://siegburg.virtualcitymap.de#{req.path}"
      return [302, { "Location" => "https://siegburg.virtualcitymap.de#{req.path}" }, []]
    end

    @app.call(env)
  end
end
