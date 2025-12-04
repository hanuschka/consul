class BaseSerializer
  def self.serialize_collection(resources, **settings)
    resources.map do |resource|
      self.new(resource, **settings).serialize
    end
  end
end
