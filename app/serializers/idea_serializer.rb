# frozen_string_literal: true

class IdeaSerializer < BaseSerializer
  attr_reader :idea

  def initialize(idea)
    @idea = idea
  end

  def serialize
    idea_data = idea.as_json(
      only: [
        :id,
        :author_id,
        :cached_votes_up,
        :comments_count,
        :created_at,
        :updated_at,
        :video_url,
        :on_behalf_of,
        :timeframe,
        :votes_needed_for_success,
        :idea_category_id,
        :idea_officer_id,
        :admin_accepted_at
      ]
    )

    idea_data.merge!(
      title: idea.title,
      description: idea.description,
      official_answer: idea.official_answer
    )

    idea_data[:status] = idea.status if idea.respond_to?(:status)

    if idea.author.present?
      idea_data[:author] = {
        id: idea.author.id,
        username: idea.author.username,
        public_name: idea.author.public_name
      }
    end

    if idea.category.present?
      idea_data[:category] = {
        id: idea.category.id,
        name: idea.category.name
      }
    end

    if idea.map_location.present?
      idea_data[:map_location] = {
        latitude: idea.map_location.latitude,
        longitude: idea.map_location.longitude,
        zoom: idea.map_location.zoom,
        approximated_address: idea.approximated_address
      }
    end

    if idea.respond_to?(:image) && idea.image.present?
      serialized_image = ImageSerializer.new(idea.image, include_variants: true).serialize
      idea_data[:image] = serialized_image if serialized_image.present?
    end

    if idea.respond_to?(:documents) && idea.documents.any?
      idea_data[:documents] = idea.documents.map do |doc|
        {
          id: doc.id,
          title: doc.title,
          attachment_file_name: doc.attachment_file_name,
          attachment_file_size: doc.attachment_file_size
        }
      end
    end

    idea_data[:remaining_days] = idea.remaining_days if idea.respond_to?(:remaining_days)

    idea_data
  end

  def self.serialize_collection(ideas)
    ideas.map { |idea| new(idea).serialize }
  end
end

