# The projekt settings the API may write: the keys of ProjektSetting.defaults,
# each with the value type /adm edits it as.
module ProjektSetting::ConfigurableKeys
  EXTERNAL_PARTICIPATION_LINK_KEY = "projekt_option.general.external_participation_link".freeze
  DEFAULT_FOOTER_TAB_KEY = "projekt_custom_feature.default_footer_tab".freeze

  class << self
    def for_projekt(projekt)
      ProjektSetting.defaults.keys.map(&:to_s).filter_map { |key| build(key, projekt) }.index_by(&:key)
    end

    private

      def build(key, projekt)
        if key.start_with?("projekt_feature.")
          ConfigurableKey.new(key, group: "projekt", type: :boolean)
        elsif key == EXTERNAL_PARTICIPATION_LINK_KEY
          ConfigurableKey.new(key, group: "projekt", type: :url, allow_blank: true)
        elsif key == DEFAULT_FOOTER_TAB_KEY
          ConfigurableKey.new(
            key,
            group: "projekt",
            type: :select,
            allow_blank: true,
            options: projekt.projekt_phases.ids.map(&:to_s)
          )
        end
      end
  end
end
