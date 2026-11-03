require_relative "../lib/middleware/downcase_route"

module Consul
  class Application < Rails::Application
    config.i18n.default_locale = :de
    config.i18n.available_locales = [:de, :en]
    config.active_model.i18n_customize_full_message = true

    config.middleware.insert_before(0, DowncaseRoute)

    def secrets
      @secrets ||= read_secrets
    end

    def credentials
      secrets
    end

    private

      def read_secrets
        secrets = ActiveSupport::OrderedOptions.new
        path = Rails.root.join("config", "secrets.yml")

        if path.exist?
          secrets_by_environment = YAML.unsafe_load(ERB.new(path.read).result) || {}

          secrets_by_environment.values_at("shared", Rails.env).compact.each do
            secrets.merge!(it.deep_symbolize_keys)
          end
        end

        secrets
      end
  end
end
