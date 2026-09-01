class MasterportalCollection < ApplicationRecord
  SHAPE_GEOMETRY_TYPES = %w[Polygon MultiPolygon].freeze

  belongs_to :projekt_phase
  has_many :masterportal_pins, dependent: :nullify
  has_many :projekt_labels, dependent: :destroy
  has_many :projekt_point_of_interest_categories, dependent: :destroy
  has_one_attached :geojson_file

  enum source: {
    geoserver: "geoserver",
    file: "file"
  }, _prefix: true

  validates :collection_id, presence: true
  validates :collection_id, uniqueness: { scope: :projekt_phase_id }
  validates :feature_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true

  scope :ordered, -> { order(:name) }

  def display_name
    name.presence || collection_id
  end

  def file_source?
    source_file?
  end

  def source_url
    return if file_source?
    return if endpoint_url.blank? || collection_id.blank?

    OgcApiFeatures::Client.items_url(endpoint_url, collection_id)
  end

  def pins_count
    masterportal_pins.count
  end

  def shape_pins?
    masterportal_pins.where("geometry ->> 'type' IN (?)", SHAPE_GEOMETRY_TYPES).exists?
  end

  def default_icon_pins?
    masterportal_pins
      .where("geometry ->> 'type' = 'Point'")
      .where("NULLIF(properties ->> 'IMAGE_URL', '') IS NULL")
      .exists?
  end

  def resources_count
    masterportal_pins.with_associated_record.distinct.count
  end

  def encoded_icon_url
    raw = icon_url
    return if raw.blank?

    Addressable::URI.parse(raw).normalize.to_s
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def import_running?
    import_status == "running"
  end

  def destroy_running?
    destroy_status == "running"
  end
end
