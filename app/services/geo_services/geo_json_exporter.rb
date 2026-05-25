class GeoServices::GeoJsonExporter < ApplicationService
  def initialize(relation, source_filter: "all")
    @relation = relation
    @source_filter = source_filter
  end

  def call
    {
      type: "FeatureCollection",
      features: build_features
    }.to_json
  end

  private

    attr_reader :relation, :source_filter

    def build_features
      features = []

      scoped_relation.includes(:map_location, :projekt_labels).find_each do |record|
        feature = feature_from(record)

        next if feature.nil?

        features << feature
      end

      features
    end

    def scoped_relation
      case source_filter
      when "masterportal"
        relation.where.not(masterportal_pin_id: nil)
      when "user"
        relation.where(masterportal_pin_id: nil)
      else
        relation
      end
    end

    def feature_from(record)
      location = record.map_location

      return nil if location.nil?
      return nil if location.latitude.blank? || location.longitude.blank?

      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [location.longitude.to_f, location.latitude.to_f]
        },
        properties: properties_for(record)
      }
    end

    def properties_for(record)
      {
        id: record.id,
        title: record.title,
        description: record.description.to_s,
        source: source_for(record),
        votes_count: votes_count_for(record),
        comments_count: comments_count_for(record),
        categories: category_names(record)
      }
    end

    def source_for(record)
      return "masterportal" if record.masterportal_pin_id.present?

      "user"
    end

    def votes_count_for(record)
      return 0 if !record.respond_to?(:cached_votes_up)

      record.cached_votes_up.to_i
    end

    def comments_count_for(record)
      return 0 if !record.respond_to?(:comments_count)

      record.comments_count.to_i
    end

    def category_names(record)
      return [] if !record.respond_to?(:projekt_labels)

      record.projekt_labels.map(&:name)
    end
end
