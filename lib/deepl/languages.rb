module Deepl
  module Languages
    TARGETS = {
      "de" => "DE",
      "en" => "EN-GB",
      "fr" => "FR",
      "es" => "ES",
      "pt" => "PT-PT",
      "pt-br" => "PT-BR",
      "nl" => "NL",
      "it" => "IT",
      "pl" => "PL",
      "ru" => "RU",
      "zh-cn" => "ZH-HANS",
      "zh-tw" => "ZH-HANT"
    }.freeze

    SOURCES = {
      "de" => "DE",
      "en" => "EN",
      "fr" => "FR",
      "es" => "ES",
      "pt" => "PT",
      "pt-br" => "PT",
      "nl" => "NL",
      "it" => "IT",
      "pl" => "PL",
      "ru" => "RU",
      "zh-cn" => "ZH",
      "zh-tw" => "ZH"
    }.freeze

    FORMALITY_TARGETS = %w[DE FR IT ES NL PL PT-PT PT-BR RU JA].freeze

    module_function

    def target_for(locale)
      TARGETS[key_for(locale)]
    end

    def source_for(locale)
      SOURCES[key_for(locale)]
    end

    def supported?(locale)
      TARGETS.key?(key_for(locale))
    end

    def supports_formality?(target_lang)
      FORMALITY_TARGETS.include?(target_lang.to_s.upcase)
    end

    def key_for(locale)
      locale.to_s.downcase
    end
  end
end
