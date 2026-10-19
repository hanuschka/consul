module Adm
  module Handbook
    SECTION_PATHS = {
      "administration"     => "administration",
      "projekts"           => "projekte",
      "landing_pages"      => "themenseiten",
      "moderation"         => "moderation",
      "deficiency_reports" => "maengelmelder",
      "municipal_plans"    => "vorhabenliste",
      "ideas"              => "ideen",
      "valuation"          => "budget-begutachtung",
      "officing"           => "abstimmungshelfer"
    }.freeze

    def self.configured?
      base_url.present?
    end

    def self.base_url
      Setting["handbook.url"].to_s.strip.chomp("/")
    end

    def self.origin
      uri = URI.parse(base_url)
      uri.port == uri.default_port ? "#{uri.scheme}://#{uri.host}" : "#{uri.scheme}://#{uri.host}:#{uri.port}"
    rescue URI::Error
      nil
    end

    def self.section_url(section_key)
      "#{base_url}/#{SECTION_PATHS.fetch(section_key)}/"
    end

    def self.page_url(page)
      return if page.blank? || !configured?

      base = URI.parse("#{base_url}/")
      candidate = URI.join(base, page.to_s)

      return unless candidate.scheme == base.scheme &&
                    candidate.host == base.host &&
                    candidate.port == base.port &&
                    candidate.path.start_with?(base.path)

      candidate.to_s
    rescue URI::Error
      nil
    end
  end
end
