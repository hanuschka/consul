# frozen_string_literal: true

require 'elasticsearch/model'

module Search::Generic
  extend ActiveSupport::Concern


  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks

    #index_name  "consul-search"

    settings index: { number_of_shards: 1 } do
      mappings dynamic: "false" do
        indexes :id
        indexes :updated_at, type: "date"
        indexes :created_at, type: "date"
        indexes :published
        indexes :geozone, type: "keyword"
        indexes :tags, type: "keyword"
        indexes :model_name, type: "keyword"
        indexes :coordinates, type: "geo_point"
        indexes :commentable_type, type: "keyword"
        indexes :commentable_id, type: "integer"
        indexes :community_id, type: "integer"
        indexes :budget_id, type: "integer"
        indexes :process_id, type: "integer"
        indexes :locales, type: "nested",
          properties: {
          "locale" => { "type" => "keyword" },
          "title" => { "type" => "text", "analyzer" => "snowball", "fielddata" => true },
          "description" => { "type" => "text", "analyzer" => "snowball", "fielddata" => true }
        }
      end
    end


    def as_indexed_json(_options = {})
      commentable_j = self.kind_of?(Comment) ?
        {
        commentable_type: commentable_type,
        commentable_id: commentable_id,
        budget_id: commentable.try("budget_id"),
        community_id: commentable.try("community_id")
      } : {}
      budget = self.kind_of?(Budget::Investment) ? {budget_id: budget_id} : {}
      legislation = self.kind_of?(Legislation::Proposal) ? {process_id: legislation_process_id} : {}

      as_json(
        only: %i[id updated_at created_at]
      ).merge({
        published: try(:hidden_at).nil? || try(:published?) ? true : false,
        geozone: try(:geozone)&.name,
        tags: try(:tags)&.category&.map(&:name),
        locales: locales,
        model_name: self.class.to_s.underscore.gsub("/", "_"),
        slug: try(:slug)
      }).merge(
        commentable_j
      ).merge(
        budget
      ).merge(
        legislation
      )
    end

    def locales
      res = if self.class == Legislation::Proposal
              I18n.available_locales.map do |l|
                {
                  locale: l,
                  title: title,
                  description: [summary, process].join(" ")
                }
              end
            else
              translations.map do |tr|
                {
                  locale: tr.locale,
                  title: tr.try(:title) || tr.try(:name),
                  description: [tr.try(:description), tr.try(:summary), tr.try(:content), tr.try(:body)].join(" ")
                }
              end
            end
      res
    end
  end
end