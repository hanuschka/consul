# frozen_string_literal: true

class IdeaCategorySerializer < BaseSerializer
  attr_reader :category

  def initialize(category, client: nil, ideas_count: nil)
    @category = category
    @client = client
    @ideas_count = ideas_count
  end

  def serialize
    category_data = category.as_json(
      only: [
        :id,
        :idea_officer_id,
        :created_at,
        :updated_at,
        :given_order,
        :color,
        :icon
      ]
    )

    category_data.merge!(
      name: category.name,
      translations: serialize_translations(category)
    )

    default_officer = category.default_idea_officer

    if default_officer.present?
      category_data[:default_idea_officer] =
        if admin_client?
          { id: default_officer.id, name: default_officer.name }
        else
          { id: default_officer.id }
        end
    end

    category_data[:ideas_count] = ideas_count

    category_data
  end

  def self.serialize_collection(categories, client: nil)
    counts = accepted_ideas_counts(categories.map(&:id))

    categories.map do |category|
      new(category, client: client, ideas_count: counts.fetch(category.id, 0)).serialize
    end
  end

  def self.accepted_ideas_counts(category_ids)
    Idea.accepted.where(idea_category_id: category_ids).group(:idea_category_id).count
  end

  private

    def ideas_count
      @ideas_count ||= self.class.accepted_ideas_counts([category.id]).fetch(category.id, 0)
    end
end
