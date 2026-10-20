require_dependency Rails.root.join("app", "models", "site_customization", "content_block").to_s

class SiteCustomization::ContentBlock < ApplicationRecord
  VALID_BLOCKS = %w[top_links footer subnavigation_left subnavigation_left_desktop subnavigation_left_mobile subnavigation_right_desktop subnavigation_right_mobile custom].freeze
  DEFAULT_MARGIN_BOTTOM = 20
  MIN_MARGIN_BOTTOM = 15
  VISIBILITY_ATTRIBUTES = %w[visible visible_from visible_until].freeze
  # Matches the editor's datetime-local inputs. Values are read and written in
  # the app time zone, which is German local time.
  VISIBILITY_TIME_FORMAT = "%Y-%m-%dT%H:%M".freeze

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
  validate :visibility_period_order
  acts_as_list scope: [:projekt_id, :newsletter_id]

  # Add-mode rows are placeholders that never existed as content, so they stay
  # hidden until the generation completes. Every other mode operates on a live
  # block: hiding those would make an existing block vanish from the page for
  # the duration of the generation, and stay gone if it fails.
  default_scope {
    where(
      "ai_generation_data IS NULL " \
      "OR ai_generation_data->>'status' = 'completed' " \
      "OR ai_generation_data->>'mode' <> 'add'"
    )
  }

  scope :with_ai_in_progress, -> {
    unscoped.where("ai_generation_data->>'status' IN (?)", %w[pending processing cancelled failed])
  }

  scope :failed_ai_placeholders, -> {
    unscoped.where(
      "ai_generation_data->>'mode' = 'add' AND ai_generation_data->>'status' = 'failed'"
    )
  }

  before_validation :repair_html_body, :sanitize_body

  after_create :touch_projekt_content_updated_at
  after_destroy :touch_projekt_content_updated_at
  after_update :touch_projekt_content_updated_at, if: :visibility_previously_changed?

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

  # body is a Globalize attribute and lives in the translations table, so a
  # raw column write on this record targets a column the table does not have.
  # Assigning and saving routes the value to the translation row instead, while
  # still skipping the validations update_columns used to skip.
  def update_without_validation!(attributes)
    assign_attributes(attributes)
    save(validate: false)
  end

  def mark_ai_generation_status!(status, extra = {})
    new_data = (ai_generation_data || {}).merge("status" => status).merge(extra.stringify_keys)
    update_column(:ai_generation_data, new_data)
  end

  # Only the step key is stored. The status endpoint translates it, because it
  # runs in the editor's request locale while the job does not.
  def mark_ai_generation_step!(step)
    mark_ai_generation_status!(ai_generation_status || "processing", step: step)
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

  # The editor works in whole minutes, so both ends of the period cover their
  # full minute: an end of 23:59 and a start of 00:00 leave no gap between two
  # consecutive blocks.
  def visibility_status(now = Time.current)
    return "hidden" unless visible?
    return "scheduled" if visible_from.present? && now < visible_from.beginning_of_minute
    return "expired" if visible_until.present? && now > visible_until.end_of_minute

    "visible"
  end

  def publicly_visible?(now = Time.current)
    visibility_status(now) == "visible"
  end

  def visibility_state
    {
      visible: visible?,
      visible_from: visible_from&.strftime(VISIBILITY_TIME_FORMAT),
      visible_until: visible_until&.strftime(VISIBILITY_TIME_FORMAT),
      status: visibility_status
    }
  end

  def visibility_previously_changed?
    saved_changes.keys.intersect?(VISIBILITY_ATTRIBUTES)
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

    touched_projekt_ids = Current.content_block_touched_projekt_ids

    if touched_projekt_ids.nil?
      projekt&.touch(:content_updated_at)
    elsif projekt_id.present?
      touched_projekt_ids << projekt_id
    end
  end

  def self.clamp_margin_bottom(margin_bottom)
    [type_for_attribute("margin_bottom").cast(margin_bottom).to_i, MIN_MARGIN_BOTTOM].max
  end

  private

  def single_parent
    if projekt_id.present? && newsletter_id.present?
      errors.add(:base, :invalid)
    end
  end

  def visibility_period_order
    return if visible_from.blank? || visible_until.blank?
    return if visible_until >= visible_from

    errors.add(:visible_until, :before_visible_from)
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
