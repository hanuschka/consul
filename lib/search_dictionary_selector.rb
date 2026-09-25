module SearchDictionarySelector
  SQL_QUERY = "SELECT cfgname FROM pg_ts_config".freeze
  I18N_TO_DICTIONARY = {
    en: "english",
    de: "german",
    fi: "finnish",
    fr: "french",
    dk: "danish",
    nl: "dutch",
    hu: "hungarian",
    it: "italian",
    nn: "norwegian",
    nb: "norwegian",
    pt: "portuguese",
    ro: "romanian",
    ru: "russian",
    es: "spanish",
    sv: "swedish",
    tr: "turkish"
  }.freeze

  class << self
    # Memoized per locale: the answer derives from I18n.default_locale and the
    # server's installed dictionaries, neither of which moves while the process
    # runs. Called from inside every search scope's lambda, so without this it
    # is a round trip to pg_ts_config on every search the site performs.
    def call
      @dictionaries ||= {}
      @dictionaries[I18n.default_locale] ||= find_from_i18n_default
    end

    private

      def find_from_i18n_default
        key_to_lookup = I18n.default_locale.to_s.split("-").first.to_sym

        dictionary = I18N_TO_DICTIONARY[key_to_lookup]
        dictionary ||= "simple"
        available_dictionaries.include?(dictionary) ? dictionary : available_dictionaries.first
      end

      def available_dictionaries
        result = ActiveRecord::Base.connection.execute(SQL_QUERY)
        result.to_a.map { |row| row["cfgname"] }
      end
  end
end
