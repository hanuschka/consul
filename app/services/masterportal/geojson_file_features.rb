class Masterportal::GeojsonFileFeatures
  MAX_FILE_SIZE = 50.megabytes

  class InvalidFile < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  def self.validate_upload!(uploaded_file)
    if uploaded_file.size.to_i > MAX_FILE_SIZE
      raise InvalidFile.new(:too_large)
    end

    content = uploaded_file.read
    uploaded_file.rewind
    parse!(content)

    true
  end

  def self.parse!(content)
    if content.to_s.strip.blank?
      raise InvalidFile.new(:empty)
    end

    body =
      begin
        JSON.parse(content)
      rescue JSON::ParserError
        raise InvalidFile.new(:invalid_json)
      end

    if !body.is_a?(Hash) || body["type"] != "FeatureCollection"
      raise InvalidFile.new(:not_feature_collection)
    end

    Array(body["features"])
  end

  def initialize(masterportal_collection:)
    @masterportal_collection = masterportal_collection
  end

  def each(&block)
    return enum_for(:each) if block.nil?

    features.each(&block)
  end

  private

    def features
      if !@masterportal_collection.geojson_file.attached?
        raise InvalidFile.new(:missing_file)
      end

      @features ||= self.class.parse!(@masterportal_collection.geojson_file.download)
    rescue ActiveStorage::FileNotFoundError
      raise InvalidFile.new(:missing_file)
    end
end
