class DowncaseRoute
  SKIP_PREFIXES = %w[
    /assets
    /rails/active_storage
    /rails/blob
    /rails/disk
    /cable
    /vcmap
    /admin
    /letter_opener
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"]

    if needs_redirect?(path)
      lowered = path.downcase
      query = env["QUERY_STRING"]
      location = !query.to_s.empty? ? "#{lowered}?#{query}" : lowered

      [301, { "Location" => location }, []]
    else
      @app.call(env)
    end
  end

  private

    def needs_redirect?(path)
      path != path.downcase && !skip_path?(path)
    end

    def skip_path?(path)
      SKIP_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end
end
