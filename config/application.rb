require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Consul
  class Application < Rails::Application
    config.load_defaults 7.2

    # Keep YJIT off: it adds memory per Puma worker on servers that already
    # run close to their limit
    config.yjit = false

    # Keep raw SQL date columns as strings, as the stats queries expect
    config.active_record.postgresql_adapter_decode_dates = false

    # Keep enqueueing jobs at once, inside the open transaction; the
    # delayed_job 4.2 adapter would otherwise hold them until commit
    config.active_job.enqueue_after_transaction_commit = :never

    # Keep ImageMagick variants: the libvips path is exposed to CVE-2026-66066
    # until the app runs a patched Rails
    config.active_storage.variant_processor = :mini_magick

    # Keep resizing and serving inline the blobs stored as image/jpg or
    # image/pjpeg, which Rails 7.0 still listed
    config.active_storage.variable_content_types += %w[image/jpg image/pjpeg]
    config.active_storage.web_image_content_types += %w[image/jpg]
    config.active_storage.content_types_allowed_inline += %w[image/jpg]

    # Derive keys with SHA1 permanently: every tenant has only ever issued
    # SHA1-signed cookies and ActiveStorage URLs, and content HTML stores the
    # URLs. Moving to SHA256 needs message-verifier rotations kept forever or
    # a rewrite of stored links; review before NIST retires SHA-1 in 2030
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1

    # Keep Net::SMTP's own open and read timeouts instead of 5 seconds
    config.action_mailer.smtp_timeout = nil

    # Keep writing caches, marshalled records and messages in formats the
    # Rails 7.0 release can read, so a rollback to it keeps the cache and
    # signed tokens. The 7.0 cache format also reads entries written by
    # Rails 6.1
    config.active_support.cache_format_version = 7.0
    config.active_record.marshalling_format_version = 6.1
    config.active_support.message_serializer = :marshal
    config.active_support.use_message_serializer_for_metadata = false

    # Keep the HTML4 sanitizer the WYSIWYG sanitizers were written against
    config.action_view.sanitizer_vendor = Rails::HTML4::Sanitizer
    config.action_text.sanitizer_vendor = Rails::HTML4::Sanitizer

    # Keep running after_commit callbacks in reverse order of definition
    config.active_record.run_after_transaction_callbacks_in_order_defined = false

    # Keep rendering button_to as input[type=submit] and stylesheet links with
    # media="screen"
    config.action_view.button_to_generates_button_tag = false
    config.action_view.apply_stylesheet_media_default = true

    # Keep inserting only the assigned columns, so database-side defaults apply
    config.active_record.partial_inserts = true

    # Don't add an empty hidden field to multiple file inputs
    config.active_storage.multiple_file_field_include_hidden = false

    # Render fields with errors without a field_with_errors wrapper; the
    # form builders mark them with the is-invalid-* classes instead
    config.action_view.field_error_proc = proc { |html_tag, _instance| html_tag }

    # Keep belongs_to fields optional by default, because that's the way
    # Rails 4 models worked
    config.active_record.belongs_to_required_by_default = false

    #    # Use local forms with `form_with`, so it works like `form_for`
    #    config.action_view.form_with_generates_remote_forms = false

    # Keep using AES-256-CBC for message encryption in case it's used
    # in any CONSUL installations
    config.active_support.use_authenticated_message_encryption = false

    # Don't enable has_many_inversing because it doesn't seem to currently
    # work with the _count database columns we use for caching purposes
    config.active_record.has_many_inversing = false

    # Keep reading existing data in the legislation_annotations ranges column
    config.active_record.yaml_column_permitted_classes = [ActiveSupport::HashWithIndifferentAccess, Symbol]

    # Handle custom exceptions
    config.action_dispatch.rescue_responses["FeatureFlags::FeatureDisabled"] = :forbidden

    # Store files locally.
    config.active_storage.service = :local

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    available_locales = [
      "ar",
      "bg",
      "bs",
      "ca",
      "cs",
      "da",
      "de",
      "el",
      "en",
      "es",
      "es-PE",
      "eu",
      "fa",
      "fr",
      "gl",
      "he",
      "hr",
      "id",
      "it",
      "ka",
      "nl",
      "oc",
      "pl",
      "pt-BR",
      "ro",
      "ru",
      "sl",
      "sq",
      "so",
      "sr",
      "sv",
      "tr",
      "uk-UA",
      "val",
      "zh-CN",
      "zh-TW"]
    config.i18n.available_locales = available_locales
    config.i18n.fallbacks.defaults = [:de]
    config.i18n.fallbacks.map = { de: :en }

    # Keep the Rails 6.1 flat locale glob: the nested locale dirs are added
    # below in override order, and a recursive glob would load them sorted
    # alphabetically first, letting base files override custom ones
    config.paths["config/locales"].glob = "*.{rb,yml}"

    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**[^custom]*", "*.{rb,yml}")]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "custom", "**", "*.{rb,yml}")]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "custom_updates", "**", "*.{rb,yml}")]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "cli", "**", "*.{rb,yml}")]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "kern", "**", "*.{rb,yml}")]

    config.assets.paths << Rails.root.join("app", "assets", "fonts")
    config.assets.paths << Rails.root.join("vendor", "assets", "fonts")
    config.assets.paths << Rails.root.join("node_modules", "jquery-ui", "themes", "base")
    config.assets.paths << Rails.root.join("node_modules", "leaflet", "dist")
    config.assets.paths << Rails.root.join("node_modules", "@kern-ux", "native", "dist", "fonts")
    config.assets.paths << Rails.root.join("node_modules", "material-symbols")
    config.assets.paths << Rails.root.join("node_modules")

    # Add lib to the autoload path
    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")
    config.time_zone = "Berlin"
    config.active_job.queue_adapter = :delayed_job

    config.action_dispatch.cookies_same_site_protection = ->(request) do
      general_allowed_paths = ["/users/send_bund_id_request"]

      if request.params[:embedded] == "true" #Current.token_user.present?
        :lax
      else
        request.path.in?(general_allowed_paths) ? :none : :lax
      end
    end

    # CONSUL specific custom overrides
    # Read more on documentation:
    # * English: https://github.com/consul/consul/blob/master/CUSTOMIZE_EN.md
    # * Spanish: https://github.com/consul/consul/blob/master/CUSTOMIZE_ES.md
    #
    #
    # A custom file shadows the original file of the same name, which it loads
    # explicitly with `load` before reopening the class.
    [
      "app/components/concerns/custom",
      "app/components/custom",
      "app/controllers/concerns/custom",
      "app/controllers/custom",
      "app/models/concerns/custom",
      "app/graphql/custom",
      "app/models/custom"
    ].each do |path|
      config.autoload_paths << Rails.root.join(path)
      config.eager_load_paths << Rails.root.join(path)
    end

    config.paths["app/views"].unshift(Rails.root.join("app", "views", "custom"))
    config.paths["app/views"].unshift(Rails.root.join("app", "views", "cli"))
  end
end

class Rails::Engine
  initializer :prepend_custom_assets_path, group: :all do |app|
    if self.class.name == "Consul::Application"
      %w[images fonts].each do |asset|
        app.config.assets.paths.unshift(Rails.root.join("app", "assets", asset, "custom").to_s)
      end
    end
  end
end

require "./config/application_custom"
