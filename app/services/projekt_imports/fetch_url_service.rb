# Reads a public web page so the AI has something to import from. Every failure
# comes back as an admin-readable message rather than an exception, because the
# import screen shows it verbatim and no projekt exists yet to fall back to.
#
# The address comes from an admin but is fetched by the server, so the checks
# below are the only thing between "any public web address" and the machines
# this one can reach that the internet cannot.
class ProjektImports::FetchUrlService < ApplicationService
  ALLOWED_SCHEMES = %w[http https].freeze
  ALLOWED_CONTENT_TYPES = %w[text/html application/xhtml+xml text/plain].freeze

  MAX_REDIRECTS = 3
  MAX_BYTES = 10.megabytes
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 20

  USER_AGENT = "Consul-ProjektImport/1.0".freeze

  def initialize(source_url:)
    @source_url = source_url.to_s.strip
  end

  def call
    uri = parse_uri
    return uri if uri.is_a?(ServiceResult)

    fetch(uri, redirects_left: MAX_REDIRECTS)
  rescue Net::OpenTimeout, Net::ReadTimeout
    failure("timeout")
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
    failure("unreachable")
  rescue OpenSSL::SSL::SSLError
    failure("tls")
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::FetchUrlService] #{e.class}: #{e.message}")
    failure("unreachable")
  end

  private

    attr_reader :source_url

    def parse_uri
      return failure("blank") if source_url.blank?

      uri = URI.parse(source_url)

      return failure("scheme") if ALLOWED_SCHEMES.exclude?(uri.scheme)
      return failure("scheme") if uri.host.blank?

      uri
    rescue URI::InvalidURIError
      failure("invalid")
    end

    def fetch(uri, redirects_left:)
      address = resolve_public_address(uri)
      return address if address.is_a?(ServiceResult)

      response = perform_request(uri, address)

      if redirect?(response)
        return follow_redirect(uri, response, redirects_left)
      end

      readable = readability_failure(response)
      return readable if readable.present?

      body = read_capped(response)
      return failure("empty") if body.blank?

      ServiceResult.success(html: body, final_url: uri.to_s)
    end

    def follow_redirect(uri, response, redirects_left)
      return failure("too_many_redirects") if redirects_left.zero?

      target = redirect_target(uri, response)
      return failure("invalid") if target.blank?

      fetch(target, redirects_left: redirects_left - 1)
    end

    def readability_failure(response)
      return failure("not_found") if response.code.to_i == 404

      if !response.is_a?(Net::HTTPSuccess)
        return failure("http_status", status: response.code)
      end

      return failure("content_type") if !html_like?(response)

      nil
    end

    # Resolved once here and handed to Net::HTTP as the address it connects to,
    # so the name cannot resolve to something else between the check and the
    # request. The Host header keeps virtual hosting and TLS working.
    def resolve_public_address(uri)
      addresses = Addrinfo.getaddrinfo(uri.host, nil, nil, :STREAM).map(&:ip_address).uniq
      return failure("unreachable") if addresses.empty?

      blocked = addresses.find { |address| private_address?(address) }
      return failure("private_address") if blocked.present?

      addresses.first
    rescue SocketError
      failure("unreachable")
    end

    def private_address?(address)
      ip = IPAddr.new(address)

      ip.loopback? || ip.private? || ip.link_local? ||
        (ip.ipv6? && ip.ipv6_unique_local?) ||
        UNSPECIFIED_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end

    # The ranges Ruby's own predicates do not cover: "this network", the
    # shared-carrier space, and the cloud metadata endpoint that sits inside
    # link-local but is worth naming for the next reader.
    UNSPECIFIED_RANGES = [
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("100.64.0.0/10"),
      IPAddr.new("169.254.169.254/32"),
      IPAddr.new("::/128")
    ].freeze

    def perform_request(uri, address)
      # The hostname stays the connection's address so SNI and certificate
      # verification still see it; ipaddr pins which machine is actually dialled
      # to the one that was just checked, closing the window where the name
      # resolves to something else between the check and the request.
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = address
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml"

      http.start { |connection| connection.request(request) }
    end

    def redirect?(response)
      response.is_a?(Net::HTTPRedirection) && response["location"].present?
    end

    def redirect_target(uri, response)
      target = URI.join(uri, response["location"])
      return nil if ALLOWED_SCHEMES.exclude?(target.scheme)
      return nil if target.host.blank?

      target
    rescue URI::Error
      nil
    end

    def html_like?(response)
      content_type = response["content-type"].to_s.split(";").first.to_s.strip.downcase
      return true if content_type.blank?

      ALLOWED_CONTENT_TYPES.include?(content_type)
    end

    # Content-Length is what the server claims; the truncation is what actually
    # bounds the read, because a server is free to send more than it announced.
    def read_capped(response)
      declared = response["content-length"].to_i
      return "" if declared > MAX_BYTES

      response.body.to_s.byteslice(0, MAX_BYTES)
    end

    def failure(reason, **interpolations)
      ServiceResult.failure(
        error: I18n.t("adm.projekts.imports.errors.url.#{reason}", **interpolations),
        error_details: { "reason" => reason, "source_url" => source_url }
      )
    end
end
