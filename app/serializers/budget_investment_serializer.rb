# frozen_string_literal: true

class BudgetInvestmentSerializer < BaseSerializer
  attr_reader :budget_investment

  def initialize(budget_investment)
    @budget_investment = budget_investment
  end

  def serialize
    investment_data = budget_investment.as_json(
      only: [
        :id,
        :author_id,
        :heading_id,
        :group_id,
        :budget_id,
        :cached_votes_up,
        :cached_votes_down,
        :comments_count,
        :confidence_score,
        :created_at,
        :updated_at,
        :video_url,
        :on_behalf_of,
        :responsible_name,
        :price,
        :feasibility,
        :valuation_finished,
        :selected,
        :visible_to_valuators,
        :physical_votes,
        :ballot_lines_count,
        :incompatible,
        :winner,
        :administrator_id
      ]
    )

    # Add translated attributes
    investment_data.merge!(
      title: budget_investment.title,
      description: budget_investment.description
    )

    # Add valuator_explanation if present
    if budget_investment.valuator_explanation.present?
      investment_data[:valuator_explanation] = budget_investment.valuator_explanation
    end

    # Add author information
    if budget_investment.author.present?
      investment_data[:author] = {
        id: budget_investment.author.id,
        username: budget_investment.author.username,
        public_name: budget_investment.author.public_name
      }
    end

    # Add heading information
    if budget_investment.heading.present?
      investment_data[:heading] = {
        id: budget_investment.heading.id,
        name: budget_investment.heading.name
      }
    end

    # Add group information
    if budget_investment.group.present?
      investment_data[:group] = {
        id: budget_investment.group.id,
        name: budget_investment.group.name
      }
    end

    # Add budget information
    if budget_investment.budget.present?
      investment_data[:budget] = {
        id: budget_investment.budget.id,
        name: budget_investment.budget.name
      }
    end

    # Add administrator information
    if budget_investment.administrator.present?
      investment_data[:administrator] = {
        id: budget_investment.administrator.id,
        name: budget_investment.administrator.user&.name
      }
    end

    # Add map location
    if budget_investment.map_location.present?
      investment_data[:map_location] = {
        latitude: budget_investment.map_location.latitude,
        longitude: budget_investment.map_location.longitude,
        zoom: budget_investment.map_location.zoom,
        approximated_address: budget_investment.approximated_address
      }
    end

    # Add image URL if present
    if budget_investment.respond_to?(:image) && budget_investment.image.present? && budget_investment.image.attached?
      investment_data[:image_url] = budget_investment.image.url
    end

    # Add documents
    if budget_investment.respond_to?(:documents) && budget_investment.documents.any?
      investment_data[:documents] = budget_investment.documents.map do |doc|
        {
          id: doc.id,
          title: doc.title,
          attachment_file_name: doc.attachment_file_name,
          attachment_file_size: doc.attachment_file_size
        }
      end
    end

    # Add tags
    if budget_investment.tag_list.any?
      investment_data[:tags] = budget_investment.tag_list
    end

    # Add custom fields
    investment_data[:code] = budget_investment.code if budget_investment.respond_to?(:code)
    investment_data[:total_votes] = budget_investment.total_votes if budget_investment.respond_to?(:total_votes)

    if budget_investment.respond_to?(:total_ballot_votes)
      investment_data[:total_ballot_votes] = budget_investment.total_ballot_votes
    end

    # Add status indicators
    investment_data[:feasible] = budget_investment.feasible?
    investment_data[:unfeasible] = budget_investment.unfeasible?
    investment_data[:undecided] = budget_investment.undecided?
    investment_data[:final_winner] = budget_investment.final_winner? if budget_investment.respond_to?(:final_winner?)

    investment_data
  end

  def self.serialize_collection(budget_investments)
    budget_investments.map { |budget_investment| new(budget_investment).serialize }
  end
end
