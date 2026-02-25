# frozen_string_literal: true

class IdeaCategorySerializer < BaseSerializer
  attr_reader :category

  def initialize(category)
    @category = category
  end

  def serialize
    category_data = category.as_json(
      only: [
        :id,
        :idea_officer_id,
        :created_at,
        :updated_at,
        :given_order
      ]
    )

    category_data.merge!(
      name: category.name
    )

    if category.default_idea_officer.present?
      category_data[:default_idea_officer] = {
        id: category.default_idea_officer.id,
        name: category.default_idea_officer.name,
        email: category.default_idea_officer.email
      }
    end

    category_data[:ideas_count] = category.ideas.count

    category_data
  end

  def self.serialize_collection(categories)
    categories.map { |category| new(category).serialize }
  end
end
