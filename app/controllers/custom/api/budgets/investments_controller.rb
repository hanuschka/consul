# frozen_string_literal: true

class Api::Budgets::InvestmentsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  before_action :find_budget, only: [:index, :create], if: -> { params[:budget_id].present? }
  before_action :find_budget_investment, only: [:show, :update, :destroy]

  def index
    check_read_access!
    budget_investments = if @budget.present?
      @budget.investments.includes(
        :author,
        :heading,
        :map_location,
        budget: {
          projekt_phase: :projekt,
          group: :heading
        }
      )
    else
      Budget::Investment.includes(
        :author,
        :heading,
        :map_location,
        budget: {
          projekt_phase: :projekt,
          group: :heading
        }
      )
    end

    budget_investments = paginate(budget_investments.order(created_at: :asc))

    budget_investments = apply_filters(budget_investments)
    budget_investments = apply_sorting(budget_investments)

    serialized_budget_investments = BudgetInvestmentSerializer.serialize_collection(budget_investments)

    render json: {
      data: { budget_investments: serialized_budget_investments },
      pagination: pagination_meta(budget_investments)
    }
  end

  def show
    check_read_access!
    serialized_budget_investment = BudgetInvestmentSerializer.new(@budget_investment).serialize

    render json: { data: { budget_investment: serialized_budget_investment } }
  end

  def create
    check_admin_access!
    find_budget unless @budget.present?
    budget_investment = @budget.investments.new(budget_investment_params)
    budget_investment.author = @current_client.content_author
    budget_investment.resource_terms = true

    if budget_investment.save
      process_image_with_base64(budget_investment, params[:budget_investment][:image_attributes])
      serialized_budget_investment = BudgetInvestmentSerializer.new(budget_investment).serialize

      render json: { data: { budget_investment: serialized_budget_investment } }, status: 201
    else
      render json: { error: { messages: budget_investment.errors.full_messages } }, status: 422
    end
  end

  def update
    check_admin_access!
    @budget_investment.assign_attributes(budget_investment_params)

    if @budget_investment.save
      process_image_with_base64(@budget_investment, params[:budget_investment][:image_attributes])
      serialized_budget_investment = BudgetInvestmentSerializer.new(@budget_investment).serialize

      render json: { data: { budget_investment: serialized_budget_investment } }
    else
      render json: { error: { messages: @budget_investment.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @budget_investment.destroy
      render json: { message: "Budget investment destroyed" }
    else
      render json: { error: { messages: @budget_investment.errors.messages } }, status: 422
    end
  end

  private

  def budget_investment_params
    params.require(:budget_investment).permit(
      :title,
      :description,
      :heading_id,
      :video_url,
      :on_behalf_of,
      :resource_terms,
      :price,
      :feasibility,
      :valuation_finished,
      :selected,
      :visible_to_valuators,
      map_location_attributes: map_location_attributes,
      documents_attributes: document_attributes,
      tag_list: []
    )
  end

  def find_budget
    @budget = Budget.find(params[:budget_id])
  end

  def find_budget_investment
    @budget_investment = Budget::Investment.includes(
      budget: {
        projekt_phase: :projekt,
        group: :heading
      }
    ).find(params[:id])
  end

  def apply_filters(budget_investments)
    if params[:heading_id].present?
      budget_investments = budget_investments.by_heading(params[:heading_id])
    end

    if params[:group_id].present?
      budget_investments = budget_investments.by_group(params[:group_id])
    end

    if params[:feasibility].present? && params[:feasibility].in?(%w[feasible unfeasible undecided])
      budget_investments = budget_investments.send(params[:feasibility])
    end

    if params[:selected].present?
      budget_investments = params[:selected] == 'true' ? budget_investments.selected : budget_investments.unselected
    end

    if params[:valuation_finished].present?
      budget_investments = params[:valuation_finished] == 'true' ? budget_investments.valuation_finished : budget_investments.valuation_open
    end

    budget_investments
  end

  def apply_sorting(budget_investments)
    order = params[:order] || 'id'

    case order
    when 'id'
      budget_investments.sort_by_id
    when 'supports'
      budget_investments.sort_by_supports
    when 'confidence_score'
      budget_investments.sort_by_confidence_score
    when 'price'
      budget_investments.sort_by_price
    when 'ballots'
      budget_investments.sort_by_ballots
    when 'newest'
      budget_investments.sort_by_newest
    else
      budget_investments.sort_by_id
    end
  end
end
