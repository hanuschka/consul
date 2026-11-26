class DowncaseRoute
  REDIRECTABLE_METHODS = %w[GET HEAD].freeze

  SKIP_PREFIXES = %w[
    /assets
    /rails/active_storage
    /rails/blob
    /rails/disk
    /blobs/
    /ckeditor/assets/
    /cable
    /vcmap
    /admin
    /letter_opener
    /unregistered_newsletter_subscribers
    /sp/SAML2
  ].freeze

  REDIRECT_CACHE_CONTROL = "max-age=3600".freeze

  LEADING_SLASHES_PATTERN = %r{\A[/\\]+}

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"]

    if needs_redirect?(env, path)
      lowered = path.downcase.sub(LEADING_SLASHES_PATTERN, "/")
      query = env["QUERY_STRING"]
      location = !query.to_s.empty? ? "#{lowered}?#{query}" : lowered

      [301, { "Location" => location, "Cache-Control" => REDIRECT_CACHE_CONTROL }, []]
    else
      @app.call(env)
    end
  end

  private

    def needs_redirect?(env, path)
      env["REQUEST_METHOD"].in?(REDIRECTABLE_METHODS) &&
        path != path.downcase &&
        !skip_path?(path)
    end

    def skip_path?(path)
      SKIP_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end
end
