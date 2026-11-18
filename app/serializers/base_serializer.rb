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
