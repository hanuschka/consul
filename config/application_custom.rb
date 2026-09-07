require_relative "../lib/middleware/downcase_route"

module Consul
  class Application < Rails::Application
    config.i18n.default_locale = :de
    config.i18n.available_locales = [:de, :en, :fr, :es, :pt, :nl, :it, :pl, :ru, :"zh-CN"]
    config.active_model.i18n_customize_full_message = true

    config.middleware.insert_before(0, DowncaseRoute)
  end
end
