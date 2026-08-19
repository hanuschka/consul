module Ai::OpenaiSdk::Client
  # The SDK retries a failed or timed-out request twice on its own. A routing
  # turn is answered while the citizen waits and holds the conversation's
  # advisory lock for as long as it runs, so two silent extra attempts spend
  # three times the clock the timeout was picked to bound. Retrying is the
  # caller's decision on this path.
  MAX_RETRIES = 0

  class ProxyUnsupportedError < StandardError; end

  # Built per call rather than memoized, like the ruby_llm contexts beside it:
  # the key is read from ExternalApiKey, so rotating it has to take effect on
  # the next message and not on the next deploy.
  def self.build
    guard_proxy!

    ::OpenAI::Client.new(**client_options)
  end

  def self.client_options
    endpoint = ::Setting["ai.llm_api_endpoint"]

    client_options = {
      api_key: ::Ai::Settings.openai_api_key,
      max_retries: MAX_RETRIES
    }

    if endpoint.present?
      client_options[:base_url] = endpoint
    end

    client_options
  end

  # A proxied box sends everything outbound through the web server's proxy, and
  # ruby_llm is handed that proxy explicitly for every provider. The SDK exposes
  # no proxy option, so carrying on here would quietly send the request straight
  # out instead. Refusing loudly is the only honest answer until the transport
  # can be given the proxy: the router's rescue turns it into a Sentry report
  # and the deterministic flow answers the citizen.
  def self.guard_proxy!
    return if ::Ai::RubyLlmFactory.proxy_uri.blank?

    raise ProxyUnsupportedError,
          "the openai SDK transport cannot honour secrets.web_server_proxy"
  end

  def self.request_options(timeout_seconds)
    return {} if timeout_seconds.blank?

    { request_options: { timeout: timeout_seconds }}
  end
end
