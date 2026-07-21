class MasterportalCollection < ApplicationRecord
  belongs_to :projekt_phase
  has_many :masterportal_pins, dependent: :nullify
  has_one_attached :geojson_file

  enum source: {
    geoserver: "geoserver",
    file: "file"
  }, _prefix: true

  validates :collection_id, presence: true
  validates :collection_id, uniqueness: { scope: :projekt_phase_id }

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

  def resources_count
    masterportal_pins.with_associated_record.distinct.count
  end

  def icon_url
    masterportal_pins.order(id: :desc).first&.feature_icon_url
  end

  def import_running?
    import_status == "running"
  end

  def destroy_running?
    destroy_status == "running"
  end
end
