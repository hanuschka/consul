require_dependency Rails.root.join("app", "models", "site_customization", "content_block").to_s

class SiteCustomization::ContentBlock < ApplicationRecord
  VALID_BLOCKS = %w[top_links footer subnavigation_left subnavigation_left_desktop subnavigation_left_mobile subnavigation_right_desktop subnavigation_right_mobile custom].freeze
  DEFAULT_MARGIN_BOTTOM = 20
  MIN_MARGIN_BOTTOM = 15

  attribute :margin_bottom, :integer, default: DEFAULT_MARGIN_BOTTOM

  translates :body, touch: true
  include MachineTranslatable

  def _assign_attributes(new_attributes)
    super

    return unless new_attributes.respond_to?(:stringify_keys)

    given_locale = new_attributes.stringify_keys["locale"]
    self[:locale] = given_locale if given_locale.present?
  end

  validates :name, presence: true, uniqueness: { scope: [:locale, :key] }, inclusion: { in: VALID_BLOCKS }

  # The key is unique across the whole table (locale_key_name_index) and encodes
  # the owning projekt, so it can never be reused between projekts.
  def self.generate_projekt_key(projekt_id, position)
    "projekt_content_block_#{projekt_id}_#{position}_#{DateTime.now.to_i}"
  end

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

  translation_class.after_commit(on: [:create, :update]) do
    globalized_model&.touch_projekt_content_updated_at if saved_changes.key?("body")
  end

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

  # Blocks are authored in a single locale. Rows for the other locales are
  # created empty on first read by custom_block_for and never filled, and
  # nothing falls back between them, so resolving the locale from a visitor
  # or editor would point half the site at empty rows.
  def self.canonical_locale
    I18n.default_locale
  end

  # Memoized per locale+key rather than batch-loaded: the table holds thousands
  # of distinct keys and a render only ever asks for a handful of them. The
  # read-only and create-on-miss paths share one registry so a block reached
  # through both is fetched once.
  def self.custom_block_for(key)
    existing_block = find_custom_block(key)

    return existing_block if existing_block.present?

    custom_blocks_registry[custom_block_registry_key(key, canonical_locale)] =
      find_or_create_by(name: 'custom', locale: canonical_locale, key: key)
  end

  def self.find_custom_block(key)
    registry = custom_blocks_registry
    memo_key = custom_block_registry_key(key, canonical_locale)

    return registry[memo_key] if registry.key?(memo_key)

    registry[memo_key] = find_by(name: 'custom', locale: canonical_locale, key: key)
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

  def touch_projekt_content_updated_at
    return if destroyed_by_association.present?

    projekt&.touch(:content_updated_at)
  end

  private

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
