# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, key: "_consul_session",
  secure: Rails.application.secrets.dig(:bund_id).present? && (Rails.env.production? || Rails.env.staging?)
