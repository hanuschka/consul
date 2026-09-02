class Api::BudgetsController < Api::BaseController
  include ImageAttributes

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_budget, only: [:show, :update, :destroy]

  def index
    check_read_access!
    budgets = if @projekt_phase.present?
      Budget.where(projekt_phase_id: @projekt_phase.id)
        .includes(:projekt_phase)
    else
      Budget.includes(:projekt_phase)
    end

    budgets =
      budgets
        .order(created_at: :asc)
        .page(params[:page])
        .per(params[:per_page] || DEFAULT_PER_PAGE)

    serialized_budgets = BudgetSerializer.serialize_collection(budgets)

    render json: {
      data: { budgets: serialized_budgets },
      pagination: pagination_meta(budgets)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    budget = @projekt_phase.build_budget(budget_attributes)

    if budget.save
      update_heading(budget)
      process_image_with_base64(budget, params[:budget][:image_attributes])
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
    if @budget.update(budget_attributes)
      update_heading(@budget)
      process_image_with_base64(@budget, params[:budget][:image_attributes])
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
      :hide_money,
      :max_number_of_winners,
      :show_results_after_first_vote,
      :show_percentage_values_only,
      :max_preselected,
      heading_attributes: [:id, :price, :population, :max_ballot_lines]
    )
  end

  # `heading` is a has_one :through, so it can neither be built nor nested-
  # assigned. A budget always carries a default group and heading, so the
  # submitted attributes are applied to that record instead.
  def budget_attributes
    budget_params.except(:heading_attributes)
  end

  def heading_params
    budget_params[:heading_attributes]
  end

  def update_heading(budget)
    return if heading_params.blank?

    heading = budget.reload.heading
    return if heading.blank?

    heading.update!(heading_params.except(:id))
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::BudgetPhase.find(params[:projekt_phase_id])
  end

  def find_budget
    @budget = Budget.find(params[:id])
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
