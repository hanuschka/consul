require_dependency "deepl/error"

module Deepl
  FREE_KEY_SUFFIX = ":fx".freeze
  PRO_HOST = "https://api.deepl.com".freeze
  FREE_HOST = "https://api-free.deepl.com".freeze
  DEFAULT_FORMALITY = "prefer_more".freeze

  def self.config
    Rails.application.secrets.deepl || {}
  end

  def self.api_key
    config[:api_key].presence
  end

  def self.free_key?
    api_key.to_s.end_with?(FREE_KEY_SUFFIX)
  end

  def self.host
    free_key? ? FREE_HOST : PRO_HOST
  end

  def self.formality
    config.fetch(:formality, DEFAULT_FORMALITY).presence
  end

  def self.allow_free_key?
    ActiveModel::Type::Boolean.new.cast(config[:allow_free_key]).present?
  end

  def self.configured?
    api_key.present? && (!free_key? || allow_free_key?)
  end

  def self.free_key_message
    if allow_free_key?
      "DeepL Free API key (#{FREE_KEY_SUFFIX}) in use, permitted by deepl.allow_free_key. The Free " \
      "tier's terms let DeepL train on submitted text — never enable this on an instance that " \
      "translates citizen content."
    else
      "DeepL Free API key (#{FREE_KEY_SUFFIX}) rejected: the Free tier's terms permit DeepL to train " \
      "on submitted text, which citizen content must never be exposed to. Translation stays disabled " \
      "until a Pro API key is configured, or deepl.allow_free_key is set for local evaluation."
    end
  end

  def self.validate!
    return unless free_key?
    return if allow_free_key?

    raise Deepl::ConfigurationError, free_key_message
  end

  def self.report_free_key
    return unless free_key?

    warn("[DeepL] #{free_key_message}")
    Rails.logger.error("[DeepL] #{free_key_message}")

    return unless defined?(Sentry)

    Sentry.capture_message("DeepL Free API key configured (allow_free_key: #{allow_free_key?})",
                           level: :error, fingerprint: ["deepl-free-key", allow_free_key?.to_s])
  end
end
