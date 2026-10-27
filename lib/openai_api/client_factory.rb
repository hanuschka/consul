# Where the credentials and the proxy are read, so OpenaiApi::Client itself
# takes them as arguments and stays a transport nobody has to stub settings
# for.
module OpenaiApi::ClientFactory
  # Built per call rather than memoized, like the ruby_llm contexts beside it:
  # the key is read from ExternalApiKey, so rotating it has to take effect on
  # the next message and not on the next deploy.
  def self.build
    ::OpenaiApi::Client.new(**client_options)
  end

  # The proxy travels with the client. A proxied box sends everything outbound
  # through the web server's proxy and ruby_llm is handed it explicitly for
  # every provider, so this transport is handed it too — the request reaches
  # the provider from those boxes rather than going straight out or being
  # refused.
  def self.client_options
    {
      api_key: ::Ai::Settings.openai_api_key,
      base_url: ::Setting["ai.llm_api_endpoint"].presence,
      proxy: ::Ai::RubyLlmFactory.proxy_uri.presence
    }
  end

  def self.request_options(timeout_seconds)
    return {} if timeout_seconds.blank?

    { request_options: { timeout: timeout_seconds }}
  end
end
