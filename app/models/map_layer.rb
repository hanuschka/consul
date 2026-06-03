class MapLayer < ApplicationRecord
  GEOJSON_CONTENT_TYPES = %w[application/geo+json application/json text/plain].freeze
  # .geojson frequently uploads as application/octet-stream when the uploader's OS
  # doesn't know the extension; accept it only when the filename confirms GeoJSON/JSON.
  GEOJSON_FALLBACK_CONTENT_TYPES = %w[application/octet-stream].freeze
  GEOJSON_EXTENSIONS = %w[.geojson .json].freeze
  GEOJSON_MAX_SIZE = 20.megabytes

  belongs_to :mappable, polymorphic: true

  enum protocol: { regular: 0, wms: 1, geojson: 2 }

  has_one_attached :geojson_file

  before_validation :normalize_config

  validate :geojson_file_presence, if: :geojson?
  validate :geojson_file_content_type, if: :geojson?
  validate :geojson_file_size, if: :geojson?
  validate :choropleth_config_consistency, if: :geojson?

  def self.default
    where(mappable_id: nil, mappable_type: nil)
  end

  def self.protocol_attributes_for_select
    protocols.map do |protocol, _|
      [protocol, I18n.t("activerecord.attributes.map_layer.protocols.#{protocol}")]
    end
  end

  def flat_style
    config.fetch("style", {})
  end

  def choropleth_config
    config.fetch("choropleth", {})
  end

  def choropleth_enabled?
    choropleth_config["enabled"].present? &&
      choropleth_config["enabled"].to_s != "false" &&
      choropleth_config["enabled"].to_s != "0"
  end

  def label_property
    config["label_property"].presence
  end

  private

    def normalize_config
      self.config ||= {}

      self.base = false if geojson?

      normalize_list("popup_properties")

      choropleth = config["choropleth"]
      return unless choropleth.is_a?(Hash)

      # Store a real boolean so the serialized JSON is unambiguous for the frontend
      # (a checkbox submits the string "0", which would be truthy in JavaScript).
      choropleth["enabled"] = ActiveModel::Type::Boolean.new.cast(choropleth["enabled"]) || false

      breaks = split_list(choropleth["breaks"])
      choropleth["breaks"] = breaks.map(&:to_f) if breaks
      colors = split_list(choropleth["colors"])
      choropleth["colors"] = colors if colors
    end

    # Coerce a comma-separated string (or array) config value into a clean array.
    def normalize_list(key)
      list = split_list(config[key])
      config[key] = list if list
    end

    def split_list(value)
      case value
      when Array
        value.map { |v| v.to_s.strip }.reject(&:blank?)
      when String
        value.split(",").map(&:strip).reject(&:blank?)
      end
    end

    def geojson_file_presence
      return if geojson_file.attached?

      errors.add(:geojson_file, :blank)
    end

    def geojson_file_content_type
      return unless geojson_file.attached?

      content_type = geojson_file.blob.content_type
      return if GEOJSON_CONTENT_TYPES.include?(content_type)
      return if GEOJSON_FALLBACK_CONTENT_TYPES.include?(content_type) && geojson_extension?

      errors.add(:geojson_file, :invalid_content_type)
    end

    def geojson_extension?
      extension = File.extname(geojson_file.blob.filename.to_s).downcase
      GEOJSON_EXTENSIONS.include?(extension)
    end

    def geojson_file_size
      return unless geojson_file.attached?
      return if geojson_file.blob.byte_size <= GEOJSON_MAX_SIZE

      errors.add(:geojson_file, :too_large, max: GEOJSON_MAX_SIZE / 1.megabyte)
    end

    def choropleth_config_consistency
      return unless choropleth_enabled?

      breaks = choropleth_config["breaks"]
      colors = choropleth_config["colors"]

      unless breaks.is_a?(Array) && colors.is_a?(Array) && colors.length == breaks.length + 1
        errors.add(:base, :choropleth_colors_count)
        return
      end

      unless breaks == breaks.sort
        errors.add(:base, :choropleth_breaks_order)
      end
    end
end
