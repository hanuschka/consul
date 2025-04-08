# frozen_string_literal: true

class Budgets::Investments::ListItemComponent < ApplicationComponent
  attr_reader :budget_investment, :budget_investment_ids, :ballot
  delegate :management_controller?, to: :helpers

  def initialize(budget_investment:, budget_investment_ids:, additional_url_params: nil, ballot:)
    @budget_investment = budget_investment
    @budget_investment_ids = budget_investment_ids
    @additional_url_params = additional_url_params
    @ballot = ballot
  end

  def component_attributes
    {
      resource: @budget_investment,
      projekt: @budget_investment.budget.projekt,
      title: budget_investment.title,
      description: budget_investment.description,
      url: budget_investment_path,
      image_url: budget_investment.image&.variant(:card_thumb),
      image_placeholder_icon_class: "fa-euro-sign"
    }
  end

  def budget_investment_path
    base_url = helpers.url_for(budget_investment)

    if @additional_url_params.present?
      base_url = UrlUtils.add_params_to_url(base_url, @additional_url_params)
    end

    base_url
  end

  def investment_status_callout
    @investment_status_callout ||= render partial: "budgets/investments/investment_status_callout", locals: { investment: budget_investment }
  end

  def location_allows_votes?
    !management_controller? &&
      controller_name != "investments" &&
      controller_name != "welcome" &&
      controller_name != "account"
  end

  def location_allows_ballots?
    !management_controller? &&
      controller_name != "investments" &&
      controller_name != "welcome" &&
      controller_name != "account"
  end

  # def show_status_message?
  #   (
  #     budget_investment.budget.accepting? ||
  #     budget_investment.budget.reviewing? ||
  #     budget_investment.budget.valuating? ||
  #     budget_investment.budget.publishing_prices? ||
  #     budget_investment.budget.reviewing_ballots? ||
  #     budget_investment.budget.finished?
  #   )
  # end

  # def status_message_class
  #   if budget_investment.budget.accepting?
  #     "success"
  #   else
  #     "warning"
  #   end
  # end
end
