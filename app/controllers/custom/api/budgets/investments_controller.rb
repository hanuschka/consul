# frozen_string_literal: true

class Api::Budgets::InvestmentsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  TRANSLATED_ATTRIBUTES = BudgetInvestmentSerializer::TRANSLATED_ATTRIBUTES

  before_action :find_budget, only: [:index, :create], if: -> { params[:budget_id].present? }
  before_action :find_budget_investment, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @budget.present?
      check_phase_visible!(@budget.projekt_phase)
    end

    investment_scope = @budget.present? ? @budget.investments : Budget::Investment

    if current_client.public_data?
      investment_scope = restrict_to_public_budget_phases(investment_scope)
    end

    budget_investments = investment_scope.preload(BudgetInvestmentSerializer::PRELOADS)
    budget_investments = paginate(apply_sorting(apply_filters(budget_investments)))

    serialized_budget_investments = BudgetInvestmentSerializer.serialize_collection(
      budget_investments,
      client: current_client,
      hide_unpublished_selection: hide_unpublished_selection?
    )

    render json: {
      data: { budget_investments: serialized_budget_investments },
      pagination: pagination_meta(budget_investments)
    }
  end

  def show
    check_read_access!
    check_phase_visible!(@budget_investment.budget.projekt_phase)

    serialized_budget_investment = BudgetInvestmentSerializer.new(
      @budget_investment,
      client: current_client,
      hide_unpublished_selection: hide_unpublished_selection?
    ).serialize

    render json: { data: { budget_investment: serialized_budget_investment } }
  end

  def create
    check_admin_access!
    find_budget if @budget.blank?
    budget_investment = @budget.investments.new(budget_investment_params.merge(external_reference_params.to_h))
    budget_investment.author = @current_client.content_author
    budget_investment.resource_terms = true
    assign_document_authors(budget_investment)
    translations = assign_requested_translations(budget_investment, :budget_investment, TRANSLATED_ATTRIBUTES)

    if save_with_translations(budget_investment, translations)
      process_image_with_base64(budget_investment, params[:budget_investment][:image_attributes])
      serialized_budget_investment = BudgetInvestmentSerializer.new(budget_investment, client: current_client).serialize

      render json: { data: { budget_investment: serialized_budget_investment } }, status: 201
    else
      render_investment_errors(budget_investment)
    end
  end

  # Staff edit an investment the way /adm does: the marked-areas check is for
  # citizens' pins, and `winner` is applied after the save, so a winner set in
  # the same request as `incompatible` survives the heading's recalculation.
  def update
    check_admin_access!
    @budget_investment.skip_marked_areas_check = true
    @budget_investment.assign_attributes(
      with_existing_map_location_id(@budget_investment, budget_investment_params.except(:winner))
    )
    assign_document_authors(@budget_investment)
    translations = assign_requested_translations(@budget_investment, :budget_investment, TRANSLATED_ATTRIBUTES)

    if save_with_winner(@budget_investment, translations)
      process_image_with_base64(@budget_investment, params[:budget_investment][:image_attributes])
      send_status_emails(@budget_investment)
      serialized_budget_investment = BudgetInvestmentSerializer.new(@budget_investment, client: current_client).serialize

      render json: { data: { budget_investment: serialized_budget_investment } }
    else
      render_investment_errors(@budget_investment)
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
    @budget_investment_params ||= with_decoded_documents(
      params.require(:budget_investment).permit(
        :title,
        :description,
        :heading_id,
        :video_url,
        :on_behalf_of,
        :resource_terms,
        :price,
        :price_explanation,
        :price_first_year,
        :duration,
        :feasibility,
        :unfeasibility_explanation,
        :valuator_explanation,
        :valuation_finished,
        :selected,
        :visible_to_valuators,
        :winner,
        :incompatible,
        :physical_votes,
        :external_url,
        :location,
        :implementation_performer,
        :implementation_contribution,
        :user_cost_estimate,
        :sentiment_id,
        projekt_label_ids: [],
        map_location_attributes: map_location_attributes_api,
        documents_attributes: document_attributes_api,
        tag_list: []
      )
    )
  end

  def render_investment_errors(budget_investment)
    render json: {
      error: { messages: TranslatedRecordErrors.full_messages(budget_investment) }
    }, status: 422
  end

  # The external reference identifies the record in the client's system, so
  # it is set once, when the record is created.
  def external_reference_params
    params.require(:budget_investment).permit(:external_source, :external_id)
  end

  # A failing `winner` update rolls the first save back; its errors are
  # reported like those of the save.
  def save_with_winner(budget_investment, translations)
    Budget::Investment.transaction do
      save_with_translations(budget_investment, translations) && apply_winner(budget_investment)
    end
  rescue ActiveRecord::RecordInvalid
    false
  end

  def apply_winner(budget_investment)
    if !budget_investment_params.key?(:winner)
      return true
    end

    budget_investment.update!(winner: budget_investment_params[:winner])
  end

  def send_status_emails(budget_investment)
    if feasibility_assessment_submitted?
      budget_investment.send_feasibility_email
    end

    if budget_investment_params.key?(:selected)
      budget_investment.send_selection_email
    end
  end

  def feasibility_assessment_submitted?
    budget_investment_params.key?(:feasibility) ||
      budget_investment_params.key?(:valuation_finished)
  end

  def find_budget
    @budget = Budget.includes(:projekt_phase).find(params[:budget_id])
  end

  def find_budget_investment
    @budget_investment = Budget::Investment.includes(BudgetInvestmentSerializer::PRELOADS).find(params[:id])
  end

  def restrict_to_public_budget_phases(scope)
    scope
      .joins(budget: :projekt_phase)
      .where(projekt_phases: { frontend_visibility: true, active: true })
  end

  def apply_filters(budget_investments)
    if params[:heading_id].present?
      budget_investments = budget_investments.by_heading(params[:heading_id])
    end

    if params[:group_id].present?
      budget_investments = budget_investments.by_group(params[:group_id])
    end

    case params[:feasibility]
    when "feasible"
      budget_investments = budget_investments.feasible
    when "unfeasible"
      budget_investments = budget_investments.unfeasible
    when "undecided"
      budget_investments = budget_investments.undecided
    end

    if params[:selected].present?
      budget_investments = filter_by_selected(budget_investments, params[:selected] == "true")
    end

    if params[:valuation_finished].present?
      budget_investments = params[:valuation_finished] == 'true' ? budget_investments.valuation_finished : budget_investments.valuation_open
    end

    budget_investments
  end

  # Every sort is a reorder ending on id, so rows with equal values keep
  # their place across pages.
  def apply_sorting(budget_investments)
    case params[:order]
    when "supports"
      budget_investments.reorder(cached_votes_up: :desc, id: :desc)
    when "confidence_score"
      budget_investments.sort_by_confidence_score
    when "price"
      budget_investments.sort_by_price
    when "ballots"
      budget_investments.sort_by_ballots
    when "newest"
      budget_investments.sort_by_newest.order(id: :desc)
    else
      budget_investments.reorder(id: :desc)
    end
  end

  def filter_by_selected(budget_investments, selected)
    scope = selected ? budget_investments.selected : budget_investments.unselected
    return scope unless hide_unpublished_selection?

    if selected
      scope.where(budget_id: public_selection_budget_ids)
    else
      scope.or(budget_investments.selected.where.not(budget_id: public_selection_budget_ids))
    end
  end

  def hide_unpublished_selection?
    !internal_api_client? && !current_client&.admin?
  end

  def public_selection_budget_ids
    budgets = @budget.present? ? Budget.where(id: @budget) : Budget.all
    @public_selection_budget_ids ||= budgets.selection_public_ids
  end
end
