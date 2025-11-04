class Api::BudgetsController < Api::BaseController
  include ImageAttributes

  before_action :find_projekt_phase, only: [:create]
  before_action :find_budget, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    budget = Budget.new(budget_params)
    budget.projekt_phase = @projekt_phase

    if budget.save
      serialized_budget = BudgetSerializer.new(budget).serialize

      render json: { data: { budget: serialized_budget } }, status: 201
    else
      render json: { error: { messages: budget.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_budget = BudgetSerializer.new(@budget).serialize

    render json: { data: { budget: serialized_budget } }
  end

  def update
    check_admin_access!
    if @budget.update(budget_params)
      serialized_budget = BudgetSerializer.new(@budget).serialize

      render json: { data: { budget: serialized_budget } }
    else
      render json: { error: { messages: @budget.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @budget.destroy
      render json: { message: "Budget destroyed" }
    else
      render json: { error: { messages: @budget.errors.messages } }, status: 422
    end
  end

  private

  def budget_params
    params.require(:budget).permit(
      :name,
      :phase,
      :currency_symbol,
      :voting_style,
      :published,
      :slug,
      image_attributes: image_attributes
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::BudgetPhase.find(params[:projekt_phase_id])
  end

  def find_budget
    @budget = Budget.find(params[:id])
  end
end
