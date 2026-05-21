require_dependency Rails.root.join("app", "models", "site_customization", "content_block").to_s

class SiteCustomization::ContentBlock < ApplicationRecord
  VALID_BLOCKS = %w[top_links footer subnavigation_left subnavigation_left_desktop subnavigation_left_mobile subnavigation_right_desktop subnavigation_right_mobile custom].freeze
  DEFAULT_MARGIN_BOTTOM = 25

  attribute :margin_bottom, :integer, default: DEFAULT_MARGIN_BOTTOM

  validates :name, presence: true, uniqueness: { scope: [:locale, :key] }, inclusion: { in: VALID_BLOCKS }
  belongs_to :projekt, optional: true
  acts_as_list scope: :projekt

  default_scope { where("ai_generation_data IS NULL OR ai_generation_data->>'status' = 'completed'") }

  scope :with_ai_in_progress, -> {
    unscoped.where("ai_generation_data->>'status' IN (?)", %w[pending processing cancelled failed])
  }

  before_validation :repair_html_body

  def ai_generation_status
    return nil if ai_generation_data.blank?

    ai_generation_data["status"]
  end

  def ai_generation_pending?
    %w[pending processing].include?(ai_generation_status)
  end

  def mark_ai_generation_status!(status, extra = {})
    new_data = (ai_generation_data || {}).merge("status" => status).merge(extra.stringify_keys)
    update_column(:ai_generation_data, new_data)
  end

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

  private

  def repair_html_body
    return if body.blank?

    self.body = Nokogiri::HTML::DocumentFragment.parse(body).to_html
  end
end
