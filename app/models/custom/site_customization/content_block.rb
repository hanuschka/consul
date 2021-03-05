require_dependency Rails.root.join("app", "models", "site_customization", "content_block").to_s

class SiteCustomization::ContentBlock < ApplicationRecord
  def self.custom_block_for(key, locale)
    locale ||= I18n.default_locale
    find_or_create_by(name: 'custom', locale: locale, key: key)
  end

  def custom?
    name == 'custom'
  end
end
