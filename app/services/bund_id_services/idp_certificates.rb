module BundIdServices
  class IdpCertificates < ApplicationService
    class Unavailable < StandardError; end

    CACHE_DURATION = 12.hours
    TIMEOUT = 5

    def initialize(idp_url)
      @idp_url = idp_url
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_DURATION) { published_certificates }
    rescue StandardError => e
      last_known = Rails.cache.read(last_known_key)
      raise Unavailable, "BundID metadata unavailable: #{e.message}" if last_known.blank?

      Rails.logger.warn("BundID metadata unavailable, using the last known certificates: #{e.message}")
      last_known
    end

    private

      def published_certificates
        metadata = OneLogin::RubySaml::IdpMetadataParser.new.parse_to_hash(download, entity_id: @idp_url)
        certificates = Array(metadata.dig(:idp_cert_multi, :signing))
        raise Unavailable, "the metadata lists no signing certificate" if certificates.empty?

        Rails.cache.write(last_known_key, certificates)
        certificates
      end

      def download
        uri = URI.parse(@idp_url)
        raise Unavailable, "the metadata URL must use https" unless uri.scheme == "https"

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                                       open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
          http.get(uri.request_uri)
        end
        raise Unavailable, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def cache_key
        "bund_id/idp_certificates/#{@idp_url}"
      end

      def last_known_key
        "bund_id/idp_certificates/last_known/#{@idp_url}"
      end
  end
end
