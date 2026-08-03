module Adm
  class FeaturesController < Adm::BaseController
    GENERAL_SETTING_KEYS = %w[
      extended_feature.general.enable_google_translate
      extended_feature.general.show_guest_login_links
    ].freeze

    GENERAL_TEXT_SETTING_KEYS = %w[
      direct_message_max_per_day
    ].freeze

    OAUTH_LOGIN_SETTING_KEYS = %w[
      feature.bund_id_login
      feature.twitter_login
      feature.facebook_login
      feature.google_login
      feature.wordpress_login
    ].freeze

    KOBIL_SETTING_KEYS = %w[
      feature.kobil_login
      feature.kobil_address_verification
    ].freeze

    def show
      authorize [:adm, Setting], :update?

      settings_by_key = Setting.where(key: displayed_setting_keys).index_by(&:key)
      ensure_settings_present!(settings_by_key)

      @general_settings = GENERAL_SETTING_KEYS.map { |key| settings_by_key[key] }
      @general_text_settings = GENERAL_TEXT_SETTING_KEYS.map { |key| settings_by_key[key] }
      @oauth_login_settings = OAUTH_LOGIN_SETTING_KEYS.map { |key| settings_by_key[key] }
      @kobil_settings = KOBIL_SETTING_KEYS.map { |key| settings_by_key[key] }

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t(".title") }
      ]
    end

    private

      def displayed_setting_keys
        GENERAL_SETTING_KEYS + GENERAL_TEXT_SETTING_KEYS + OAUTH_LOGIN_SETTING_KEYS + KOBIL_SETTING_KEYS
      end

      # Skipping an absent row would render the page with the toggle simply
      # missing: the admin cannot enable the feature and has no error to report.
      # Naming the keys points straight at the unseeded install.
      def ensure_settings_present!(settings_by_key)
        missing = displayed_setting_keys - settings_by_key.keys
        return if missing.empty?

        raise ActiveRecord::RecordNotFound,
          "Missing Setting rows: #{missing.join(', ')}. Run rake settings:add_new_settings."
      end
  end
end
