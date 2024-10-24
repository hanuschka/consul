require_dependency Rails.root.join("app", "models", "site_customization", "content_block").to_s

class SiteCustomization::ContentBlock < ApplicationRecord
  VALID_BLOCKS = %w[top_links footer subnavigation_left subnavigation_left_desktop subnavigation_left_mobile subnavigation_right_desktop subnavigation_right_mobile custom].freeze

  validates :name, presence: true, uniqueness: { scope: [:locale, :key] }, inclusion: { in: VALID_BLOCKS }
  belongs_to :projekt, optional: true
  acts_as_list scope: :projekt

  def self.custom_block_for(key, locale)
    locale ||= I18n.default_locale
    find_or_create_by(name: 'custom', locale: locale, key: key)
  end

  def custom?
    name == 'custom'
  end

  def self.sort(ordered_array)
    ordered_array.each_with_index do |record_id, order|
      find(record_id).update_column(:position, (order + 1))
    end
  end
end
