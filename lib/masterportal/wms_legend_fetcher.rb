require "faraday"
require "stringio"

module Masterportal
  module WmsLegendFetcher
    CACHE_TTL = 24.hours
    CONNECT_TIMEOUT = 10
    READ_TIMEOUT = 30
    USER_AGENT = "Consul-Masterportal/#{Rails.version}"

    module_function

    def call(wms_url:, layer:, format: "image/png")
      cache_key = build_cache_key(wms_url, layer, format)
      bytes = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        download(wms_url: wms_url, layer: layer, format: format)
      end

      return nil if bytes.blank?

      {
        io: StringIO.new(bytes),
        filename: "#{layer}.png",
        content_type: format
      }
    end

    def download(wms_url:, layer:, format:)
      response = connection.get(wms_url, {
        SERVICE: "WMS",
        REQUEST: "GetLegendGraphic",
        VERSION: "1.3.0",
        FORMAT: format,
        LAYER: layer
      })

      return nil if !response.success?
      return nil if !response.headers["content-type"].to_s.start_with?("image/")

      response.body
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.options.timeout = READ_TIMEOUT
        f.options.open_timeout = CONNECT_TIMEOUT
        f.headers["User-Agent"] = USER_AGENT
        f.adapter Faraday.default_adapter
      end
    end

    def build_cache_key(wms_url, layer, format)
      digest = Digest::SHA256.hexdigest("#{wms_url}|#{layer}|#{format}")
      "masterportal/wms_legend/#{digest}"
    end
  end
end
