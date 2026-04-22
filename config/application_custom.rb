require_relative "../lib/middleware/downcase_route"

module Consul
  class Application < Rails::Application
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :de]

    config.middleware.insert_before(0, DowncaseRoute)
  end
end
