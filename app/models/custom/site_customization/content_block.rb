require_dependency Rails.root.join("app", "models", "site_customization", "content_block").to_s

class SiteCustomization::ContentBlock < ApplicationRecord
  VALID_BLOCKS = %w[top_links footer subnavigation_left subnavigation_left_desktop subnavigation_left_mobile subnavigation_right_desktop subnavigation_right_mobile custom].freeze
  DEFAULT_MARGIN_BOTTOM = 20
  MIN_MARGIN_BOTTOM = 15

  attribute :margin_bottom, :integer, default: DEFAULT_MARGIN_BOTTOM

  validates :name, presence: true, uniqueness: { scope: [:locale, :key] }, inclusion: { in: VALID_BLOCKS }
  belongs_to :projekt, optional: true
  belongs_to :newsletter, optional: true
  validate :single_parent
  acts_as_list scope: [:projekt_id, :newsletter_id]

  default_scope { where("ai_generation_data IS NULL OR ai_generation_data->>'status' = 'completed'") }

  scope :with_ai_in_progress, -> {
    unscoped.where("ai_generation_data->>'status' IN (?)", %w[pending processing cancelled failed])
  }

  before_validation :repair_html_body, :sanitize_body

  after_create :touch_projekt_content_updated_at
  after_destroy :touch_projekt_content_updated_at
  after_update :touch_projekt_content_updated_at, if: :saved_change_to_body?

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

  # Memoized per locale+key rather than batch-loaded: the table holds thousands
  # of distinct keys and a render only ever asks for a handful of them. The
  # read-only and create-on-miss paths share one registry so a block reached
  # through both is fetched once.
  def self.custom_block_for(key, locale)
    locale ||= I18n.default_locale
    existing_block = find_custom_block(key, locale)

    return existing_block if existing_block.present?

    custom_blocks_registry[custom_block_registry_key(key, locale)] =
      find_or_create_by(name: 'custom', locale: locale, key: key)
  end

  def self.find_custom_block(key, locale)
    locale ||= I18n.default_locale
    registry = custom_blocks_registry
    memo_key = custom_block_registry_key(key, locale)

    return registry[memo_key] if registry.key?(memo_key)

    registry[memo_key] = find_by(name: 'custom', locale: locale, key: key)
  end

  def self.custom_blocks_registry
    Current.custom_content_blocks ||= {}
  end

  def self.custom_block_registry_key(key, locale)
    [locale.to_s, key]
  end

  def custom?
    name == 'custom'
  end

  def self.sort(ordered_array)
    ordered_array.each_with_index do |record_id, order|
      find(record_id).update_column(:position, (order + 1))
    end
  end

  def body_stripped?
    !!@body_stripped
  end

  private

  def touch_projekt_content_updated_at
    return if destroyed_by_association.present?

    projekt&.touch(:content_updated_at)
  end

  def single_parent
    if projekt_id.present? && newsletter_id.present?
      errors.add(:base, :invalid)
    end
  end

  def repair_html_body
    return if body.blank?

    self.body = Nokogiri::HTML::DocumentFragment.parse(body).to_html
  end

  def sanitize_body
    return if body.blank?

    sanitizer = AdminWYSIWYGSanitizer.new
    original = body
    self.body = sanitizer.sanitize(body)
    @body_stripped = sanitizer.stripped?(original, body)
  end
end
