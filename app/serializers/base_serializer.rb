class BaseSerializer
  def self.serialize_collection(resources, **settings)
    resources.map do |resource|
      self.new(resource, **settings).serialize
    end
  end

  private

    attr_reader :client

    def admin_client?
      client.present? && client.admin?
    end

    def serialize_translations(record, attribute_names = record.class.translated_attribute_names)
      TranslationsSerializer.new(record, attribute_names).serialize
    end

    def serialize_map_location(map_location)
      return nil if map_location.blank?

      MapLocationSerializer.new(map_location).serialize
    end

    # Records a client created carry the client's own reference; records
    # imported from Masterportal carry the id of their Masterportal feature.
    def serialize_external_reference(record)
      if record.external_id.present?
        { external_source: record.external_source, external_id: record.external_id }
      elsif record.masterportal_pin.present?
        { external_source: "masterportal", external_id: record.masterportal_pin.external_id }
      else
        { external_source: nil, external_id: nil }
      end
    end

    def serialize_author(user)
      AuthorSerializer.new(user, client: client).serialize
    end

    def serialize_on_behalf_of_author(resource)
      author_data = serialize_author(resource.author)

      if resource.on_behalf_of.present?
        author_data[:public_name] = nil
      end

      author_data
    end
end
