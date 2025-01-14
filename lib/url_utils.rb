module UrlUtils
  def self.add_params_to_url(url, params)
    uri = URI.parse(url)
    existing_params = Rack::Utils.parse_query(uri.query)
    updated_params = existing_params.merge(params)
    uri.query = updated_params.to_query
    uri.to_s
  end
end
