# Instance-wide map layers (no projekt or phase). They act as templates: a new
# projekt gets its own copies, so changing them leaves existing projekts as
# they are.
class Api::Configuration::MapLayersController < Api::Configuration::BaseController
  PROVIDER_FORMAT = %r{\Ahttps?://\S+\z}i
  ATTRIBUTION_TAGS = %w[a].freeze
  ATTRIBUTION_ATTRIBUTES = %w[href target rel].freeze

  ATTRIBUTE_DEFINITIONS = {
    "name" => TypedValueParser::Definition.new(type: :string),
    "layer_names" => TypedValueParser::Definition.new(type: :string, allow_blank: true, max_length: 1000),
    "provider" => TypedValueParser::Definition.new(type: :string, allow_blank: true, max_length: 2048),
    "attribution" => TypedValueParser::Definition.new(type: :string, allow_blank: true, max_length: 1000),
    "protocol" => TypedValueParser::Definition.new(type: :select, options: MapLayer.protocols.keys),
    "opacity" => TypedValueParser::Definition.new(type: :decimal, min: 0, max: 1),
    "base" => TypedValueParser::Definition.new(type: :boolean),
    "show_by_default" => TypedValueParser::Definition.new(type: :boolean),
    "transparent" => TypedValueParser::Definition.new(type: :boolean)
  }.freeze

  CONFIG_PERMITTED_PARAMS = [
    :label_property,
    :popup_properties,
    { popup_properties: [] },
    { style: [:fillColor, :fillOpacity, :color, :weight] },
    {
      choropleth: [
        :enabled, :property, :legend_title, :no_data_color, :breaks, :colors,
        { breaks: [], colors: [] }
      ]
    }
  ].freeze

  before_action :find_map_layer, only: [:show, :update, :destroy]

  def index
    map_layers = paginate(MapLayer.default.with_attached_geojson_file.order(:id))

    render json: {
      data: { map_layers: map_layers.map { |map_layer| serialize(map_layer) } },
      pagination: pagination_meta(map_layers)
    }
  end

  def show
    render json: { data: { map_layer: serialize(@map_layer) } }
  end

  def create
    save_map_layer(MapLayer.new(mappable: nil), :created)
  end

  def update
    save_map_layer(@map_layer, :ok)
  end

  def destroy
    @map_layer.destroy!

    render json: { data: { message: "Map layer deleted" } }
  end

  private

    def find_map_layer
      @map_layer = MapLayer.default.find(params[:id])
    end

    def map_layer_param
      map_layer = params.require(:map_layer)

      if map_layer.is_a?(ActionController::Parameters)
        map_layer
      else
        raise ActionController::ParameterMissing, :map_layer
      end
    end

    def save_map_layer(map_layer, success_status)
      attributes, errors = parsed_attributes
      map_layer.assign_attributes(attributes)

      if map_layer.name.blank?
        errors["name"] ||= ["can't be blank"]
      end

      if errors.any?
        render_invalid_values(errors)

        return
      end

      previous_blob = map_layer.geojson_file.attached? ? map_layer.geojson_file.blob : nil
      attach_geojson_file(map_layer)

      if map_layer.save
        audit_geojson_change(map_layer, previous_blob)

        render json: { data: { map_layer: serialize(map_layer) } }, status: success_status
      else
        render_record_errors(map_layer)
      end
    end

    def parsed_attributes
      raw_attributes = map_layer_param.to_unsafe_h.slice(*ATTRIBUTE_DEFINITIONS.keys)
      errors = {}
      attributes = {}

      raw_attributes.each do |attribute_name, raw_value|
        result = TypedValueParser.parse(raw_value, ATTRIBUTE_DEFINITIONS.fetch(attribute_name))

        if result.valid?
          attributes[attribute_name] = result.value
        else
          errors[attribute_name] = [result.error]
        end
      end

      if attributes["provider"].present? && !attributes["provider"].match?(PROVIDER_FORMAT)
        errors["provider"] = ["must be an http or https tile or service URL"]
      end

      if attributes.key?("attribution")
        attributes["attribution"] = sanitized_attribution(attributes["attribution"])
      end

      if map_layer_param.key?(:config)
        attributes["config"] = config_param
      end

      [attributes, errors]
    end

    def config_param
      config = map_layer_param[:config]

      if config.is_a?(ActionController::Parameters)
        config.permit(*CONFIG_PERMITTED_PARAMS).to_h
      else
        {}
      end
    end

    # Leaflet writes the attribution into the page as HTML, so only links stay.
    def sanitized_attribution(attribution)
      Rails::HTML5::SafeListSanitizer.new.sanitize(
        attribution.to_s, tags: ATTRIBUTION_TAGS, attributes: ATTRIBUTION_ATTRIBUTES
      )
    end

    def attach_geojson_file(map_layer)
      encoded_file = map_layer_param[:geojson_file]
      return if encoded_file.blank?

      map_layer.geojson_file = decoded_attachment(encoded_file, map_layer.name.presence || "map_layer")
    end

    def audit_geojson_change(map_layer, previous_blob)
      current_blob = map_layer.geojson_file.attached? ? map_layer.geojson_file.blob : nil

      if previous_blob&.id != current_blob&.id
        audit_attachment_change(map_layer, :geojson_file, previous_blob, current_blob)
      end
    end

    def serialize(map_layer)
      {
        id: map_layer.id,
        name: map_layer.name,
        provider: map_layer.provider,
        attribution: map_layer.attribution,
        layer_names: map_layer.layer_names,
        protocol: map_layer.protocol,
        base: map_layer.base,
        show_by_default: map_layer.show_by_default,
        transparent: map_layer.transparent,
        opacity: map_layer.opacity&.to_f,
        config: map_layer.config,
        geojson_file: serialize_attachment(map_layer.geojson_file),
        created_at: map_layer.created_at,
        updated_at: map_layer.updated_at
      }
    end
end
