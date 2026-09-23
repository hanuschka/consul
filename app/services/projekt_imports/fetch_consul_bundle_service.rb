# Fetches a projekt from another Consul instance and checks, before anything is
# built from it, that this instance can read the shape it came in. Rebuilding
# half a projekt from an unread version is worse than refusing, and refusing at
# this point costs the admin nothing — no projekt exists yet.
class ProjektImports::FetchConsulBundleService < ApplicationService
  def initialize(source_url:)
    @source_url = source_url.to_s.strip
  end

  def call
    return failure("blank") if source_url.blank?
    return failure("invalid") if !valid_http_url?

    response = ::DtApi::Client.new.projekt_exports.fetch(source_url)
    return failure("unreachable") if !response.success?

    bundle = response.parsed_response&.dig("export")
    return failure("empty") if bundle.blank?

    version = bundle["format_version"]
    if !supported_version?(version)
      return failure("unsupported_format", version: version.to_s.presence || "?")
    end

    ServiceResult.success(bundle: bundle)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::FetchConsulBundleService] #{e.class}: #{e.message}")
    Sentry.capture_exception(e, extra: { source_url: source_url }) if defined?(Sentry)

    failure("unreachable")
  end

  private

    attr_reader :source_url

    def valid_http_url?
      uri = URI.parse(source_url)

      %w[http https].include?(uri.scheme) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def supported_version?(version)
      ::Projekts::CrossInstanceImport::ImportService::SUPPORTED_FORMAT_VERSIONS.include?(version)
    end

    def failure(reason, **interpolations)
      ServiceResult.failure(
        error: I18n.t("adm.projekts.imports.errors.consul_projekt.#{reason}", **interpolations),
        error_details: { "reason" => reason, "source_url" => source_url }
      )
    end
end
