require "faraday"
require "stringio"

class Masterportal::RemoteIconDownloader < ApplicationService
  CONNECT_TIMEOUT = 5
  READ_TIMEOUT = 10
  ALLOWED_CONTENT_TYPES = ProjektPointOfInterestCategory::ALLOWED_ICON_CONTENT_TYPES
  MAX_BYTE_SIZE = ProjektPointOfInterestCategory::MAX_ICON_BYTE_SIZE

  def initialize(url:)
    @url = url.to_s.strip
  end

  def call
    return nil if !http_url?

    response = connection.get(@url)
    return nil if !response.success?

    data = response.body.to_s
    content_type = response.headers["content-type"].to_s.split(";").first.to_s.strip

    return nil if !valid?(data, content_type)

    { io: StringIO.new(data), filename: filename, content_type: content_type }
  rescue Faraday::Error, URI::InvalidURIError => e
    Sentry.capture_exception(e) if defined?(Sentry)

    nil
  end

  private

    def http_url?
      return false if @url.blank?

      %w[http https].include?(URI.parse(@url).scheme)
    rescue URI::InvalidURIError
      false
    end

    def valid?(data, content_type)
      return false if ALLOWED_CONTENT_TYPES.exclude?(content_type)
      return false if data.bytesize > MAX_BYTE_SIZE
      return false if content_type == "image/svg+xml" && !Masterportal::SvgSanitizer.safe?(data)

      true
    end

    def filename
      base = File.basename(URI.parse(@url).path.to_s).presence || "icon"
      base.include?(".") ? base : "#{base}.svg"
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.options.timeout = READ_TIMEOUT
        f.options.open_timeout = CONNECT_TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end
end
