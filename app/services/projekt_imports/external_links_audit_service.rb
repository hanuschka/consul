# Lists the outside hosts an imported projekt will point its visitors at. The
# addresses came out of a third-party document by way of a model, so they are
# kept as written but named in the import warnings, where the admin reviews
# them before the projekt goes live.
class ProjektImports::ExternalLinksAuditService < ApplicationService
  LINK_SELECTORS = "a[href], iframe[src]".freeze

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    hosts = external_hosts

    if hosts.present?
      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.external_links", hosts: hosts.join(", "))
      )
    end

    ServiceResult.success(hosts: hosts)
  end

  private

    attr_reader :projekt_import

    def external_hosts
      urls = content_block_urls + phase_urls

      urls.filter_map { |url| host_of(url) }.uniq.sort - own_hosts
    end

    def content_block_urls
      Array(data["content_blocks"]).flat_map do |block|
        fragment = Nokogiri::HTML::DocumentFragment.parse(block["html"].to_s)

        fragment.css(LINK_SELECTORS).map { |node| node["href"] || node["src"] }
      end
    end

    def phase_urls
      Array(data["phases"]).flat_map do |phase|
        [
          phase.dig("iframe", "url"),
          *Array(phase["livestreams"]).map { |livestream| livestream["url"] },
          *Array(phase["events"]).map { |event| event["weblink"] }
        ]
      end
    end

    def host_of(url)
      uri = URI.parse(url.to_s.strip)
      return nil if !uri.is_a?(URI::HTTP)

      uri.host&.downcase
    rescue URI::Error
      nil
    end

    def own_hosts
      [UrlOptions.default[:host]].compact.map(&:downcase)
    end

    def data
      projekt_import.ai_result || {}
    end
end
