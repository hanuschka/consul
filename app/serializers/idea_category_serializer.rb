# frozen_string_literal: true

class IdeaCategorySerializer < BaseSerializer
  attr_reader :category

  def initialize(category, client: nil)
    @category = category
    @client = client
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

    default_officer = category.default_idea_officer

    if default_officer.present?
      category_data[:default_idea_officer] =
        if admin_client?
          { id: default_officer.id, name: default_officer.name }
        else
          { id: default_officer.id }
        end
    end

    category_data[:ideas_count] = category.ideas.count

    category_data
  end

  def self.serialize_collection(categories, client: nil)
    categories.map { |category| new(category, client: client).serialize }
  end
end
