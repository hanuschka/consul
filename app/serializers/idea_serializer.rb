# frozen_string_literal: true

class IdeaSerializer < BaseSerializer
  PUBLIC_TRANSLATED_ATTRIBUTES = %w[title description].freeze
  ADMIN_TRANSLATED_ATTRIBUTES = %w[title description official_answer].freeze

  attr_reader :idea

  def initialize(idea, client: nil)
    @idea = idea
    @client = client
  end

  def serialize
    idea_data = idea.as_json(
      only: [
        :id,
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
      description: idea.description
    )

    if admin_client?
      idea_data[:author_id] = idea.author_id
      idea_data[:official_answer] = idea.official_answer
      idea_data[:translations] = serialize_translations(idea, ADMIN_TRANSLATED_ATTRIBUTES)
    else
      idea_data[:translations] = serialize_translations(idea, PUBLIC_TRANSLATED_ATTRIBUTES)
    end

    idea_data[:status] = idea.status if idea.respond_to?(:status)

    if idea.author.present?
      idea_data[:author] = serialize_on_behalf_of_author(idea)
    end

    if idea.category.present?
      idea_data[:category] = {
        id: idea.category.id,
        name: idea.category.name,
        color: idea.category.color,
        icon: idea.category.icon
      }
    end

    idea_data[:map_location] = serialize_map_location(idea.map_location)

    if idea.respond_to?(:image) && idea.image.present?
      serialized_image = ImageSerializer.new(idea.image, include_variants: true).serialize
      idea_data[:image] = serialized_image if serialized_image.present?
    end

    if idea.respond_to?(:documents) && idea.documents.any?
      idea_data[:documents] = DocumentSerializer.serialize_collection(idea.documents)
    end

    idea_data[:remaining_days] = idea.remaining_days if idea.respond_to?(:remaining_days)

    idea_data
  end

  def self.serialize_collection(ideas, client: nil)
    ideas.map { |idea| new(idea, client: client).serialize }
  end
end

