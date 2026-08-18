require_dependency "deepl/error"

class Deepl::Client
  include HTTParty

  open_timeout 5
  read_timeout 120

  MAX_TEXTS_PER_REQUEST = 50
  MAX_REQUEST_BYTES = 128 * 1024
  REQUEST_OVERHEAD_BYTES = 4_096
  MAX_TEXT_BYTES = MAX_REQUEST_BYTES - REQUEST_OVERHEAD_BYTES
  TRIPPING_STATUSES = [401, 403, 429, 456].freeze
  TRANSLATE_OPTIONS = %i[tag_handling ignore_tags preserve_formatting split_sentences context].freeze
  NETWORK_ERRORS = [
    Timeout::Error,
    EOFError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::EPIPE,
    Errno::ETIMEDOUT,
    SocketError,
    OpenSSL::SSL::SSLError
  ].freeze

  def translate(texts, target_locale:, source_locale: nil, **options)
    values = Array(texts)
    pending = values.each_with_index.reject { |text, _index| text.to_s.blank? }
    return values.dup if pending.empty?

    target_lang = target_lang_for(target_locale)
    source_lang = source_locale.present? ? source_lang_for(source_locale) : nil
    results = values.dup

    chunks(pending).each do |chunk|
      translated = request_translation(chunk.map(&:first), target_lang:, source_lang:, options:)

      chunk.each_with_index { |(_text, index), position| results[index] = translated[position] }
    end

    results
  end

  def usage
    get("/v2/usage")
  end

  private

    def request_translation(texts, target_lang:, source_lang:, options:)
      payload = encoded_payload(texts, target_lang:, source_lang:, options:)
      response = post("/v2/translate", payload)
      translations = response.is_a?(Hash) ? response["translations"] : nil

      unless translations.is_a?(Array) && translations.size == texts.size
        raise Deepl::ApiError,
          "DeepL returned #{translations.is_a?(Array) ? translations.size : "no"} translations " \
          "for #{texts.size} texts"
      end

      translated = translations.map { |translation| translation.is_a?(Hash) ? translation["text"] : nil }
      raise Deepl::ApiError, "DeepL returned a translation without a text field" if translated.any?(&:nil?)

      translated
    end

    def encoded_payload(texts, target_lang:, source_lang:, options:)
      payload = translation_body(texts, target_lang:, source_lang:, options:).to_json
      return payload if payload.bytesize <= MAX_REQUEST_BYTES

      raise Deepl::RequestTooLargeError,
        "request body of #{payload.bytesize} bytes exceeds the #{MAX_REQUEST_BYTES} byte limit"
    end

    def translation_body(texts, target_lang:, source_lang:, options:)
      unknown_options = options.keys - TRANSLATE_OPTIONS
      raise ArgumentError, "unknown DeepL options: #{unknown_options.join(", ")}" if unknown_options.any?

      body = options.compact
      body[:ignore_tags] = Array(body[:ignore_tags]) if body.key?(:ignore_tags)
      body[:text] = texts
      body[:target_lang] = target_lang
      body[:source_lang] = source_lang if source_lang.present?
      body[:formality] = Deepl.formality if send_formality?(target_lang)

      body
    end

    def send_formality?(target_lang)
      Deepl.formality.present? && Deepl::Languages.supports_formality?(target_lang)
    end

    def chunks(pending)
      chunks = []
      current = []
      current_bytes = 0

      pending.each do |pair|
        bytes = encoded_size(pair.first)
        ensure_text_fits!(bytes)

        if current.size >= MAX_TEXTS_PER_REQUEST || current_bytes + bytes > MAX_TEXT_BYTES
          chunks << current
          current = []
          current_bytes = 0
        end

        current << pair
        current_bytes += bytes
      end

      chunks << current if current.any?
      chunks
    end

    def get(path)
      perform(:get, path)
    end

    def post(path, body)
      perform(:post, path, body:)
    end

    def perform(verb, path, body: nil)
      ensure_configured!
      Deepl::CircuitBreaker.guard!(path)

      handle_response(execute(verb, path, body:), context: path)
    rescue *NETWORK_ERRORS => e
      Deepl::CircuitBreaker.record_failure
      Deepl::ErrorReporter.report_exception(e, context: path)

      raise Deepl::ConnectionError, "DeepL request failed: #{e.class}"
    end

    def execute(verb, path, body:)
      request_options = { headers: headers }
      request_options[:body] = body unless body.nil?

      self.class.public_send(verb, "#{Deepl.host}#{path}", **request_options)
    end

    def handle_response(response, context:)
      if response.success?
        Deepl::CircuitBreaker.record_success

        response.parsed_response
      else
        Deepl::CircuitBreaker.record_failure if trips_circuit?(response.code)
        Deepl::ErrorReporter.report_error(response, context:)

        raise Deepl::Error.from_response(response)
      end
    end

    def trips_circuit?(status)
      status.to_i >= 500 || TRIPPING_STATUSES.include?(status.to_i)
    end

    def headers
      {
        "Authorization" => "DeepL-Auth-Key #{Deepl.api_key}",
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
    end

    def target_lang_for(locale)
      target_lang = Deepl::Languages.target_for(locale)
      return target_lang if target_lang.present?

      raise Deepl::UnsupportedLanguageError, "no DeepL target language for locale #{locale.inspect}"
    end

    def source_lang_for(locale)
      source_lang = Deepl::Languages.source_for(locale)
      return source_lang if source_lang.present?

      raise Deepl::UnsupportedLanguageError, "no DeepL source language for locale #{locale.inspect}"
    end

    def encoded_size(text)
      text.to_json.bytesize + 1
    end

    def ensure_text_fits!(bytes)
      return if bytes <= MAX_TEXT_BYTES

      raise Deepl::RequestTooLargeError,
        "single text of #{bytes} encoded bytes exceeds the #{MAX_TEXT_BYTES} byte text budget"
    end

    def ensure_configured!
      Deepl.validate!
      return if Deepl.api_key.present?

      raise Deepl::ConfigurationError, "DeepL is not configured (secrets: deepl.api_key)"
    end
end
