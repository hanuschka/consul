class Api::BudgetsController < Api::BaseController
  include ImageAttributes

  TRANSLATED_ATTRIBUTES = BudgetSerializer::TRANSLATED_ATTRIBUTES
  NAME_TRANSLATED_ATTRIBUTES = %w[name].freeze

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_budget, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present? && phase_hidden_from_client?(@projekt_phase)
      raise ForbiddenError, "Access denied"
    end

    budgets =
      if @projekt_phase.present?
        Budget.where(projekt_phase_id: @projekt_phase.id)
      else
        Budget.all
      end

    if current_client.public_data?
      budgets = restrict_to_public_phases(budgets)
    end

    budgets = paginate(budgets.preload(BudgetSerializer::PRELOADS).order(created_at: :asc))

    serialized_budgets = BudgetSerializer.serialize_collection(budgets)

    render json: {
      data: { budgets: serialized_budgets },
      pagination: pagination_meta(budgets)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase if @projekt_phase.blank?
    budget = @projekt_phase.build_budget(budget_attributes)
    translations = assign_requested_translations(budget, :budget, TRANSLATED_ATTRIBUTES)

    budget_saved =
      Budget.transaction do
        save_with_translations(budget, translations) && update_group_and_heading(budget)
      end

    if budget_saved
      process_image_with_base64(budget, params[:budget][:image_attributes])
      serialized_budget = BudgetSerializer.new(budget.reload).serialize

      render json: { data: { budget: serialized_budget } }, status: 201
    else
      render_translated_record_errors(budget)
    end
  end

  def show
    check_read_access!
    check_phase_visible!(@budget.projekt_phase)

    serialized_budget = BudgetSerializer.new(@budget).serialize

    render json: { data: { budget: serialized_budget } }
  end

  def update
    check_admin_access!
    @budget.assign_attributes(budget_attributes)
    translations = assign_requested_translations(@budget, :budget, TRANSLATED_ATTRIBUTES)

    budget_saved =
      Budget.transaction do
        save_with_translations(@budget, translations) && update_group_and_heading(@budget)
      end

    if budget_saved
      process_image_with_base64(@budget, params[:budget][:image_attributes])
      serialized_budget = BudgetSerializer.new(@budget.reload).serialize

      render json: { data: { budget: serialized_budget } }
    else
      render_translated_record_errors(@budget)
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
      :main_link_text,
      :main_link_url,
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
      group_attributes: [:name],
      heading_attributes: [:id, :name, :price, :population, :max_ballot_lines]
    )
  end

  # `heading` is a has_one :through, so it can neither be built nor nested-
  # assigned. A budget always carries a default group and heading, so the
  # submitted attributes are applied to those records instead.
  def budget_attributes
    budget_params.except(:group_attributes, :heading_attributes)
  end

  # Runs inside the budget's transaction: a group or heading that fails to
  # save raises, which rolls the budget back and answers 422 with its errors.
  def update_group_and_heading(budget)
    budget.reload
    update_named_record(budget.group, :group_attributes)
    update_named_record(budget.heading, :heading_attributes)

    true
  end

  def update_named_record(record, attributes_key)
    attributes = budget_params[attributes_key].to_h.except("id")
    translations_param = params.dig(:budget, attributes_key, :translations)
    return if record.blank?

    if attributes.blank? && translations_param.blank?
      return
    end

    locales_error = unsupported_locales_error(translations_param)

    if locales_error.present?
      raise UnsupportedLocalesError, locales_error.transform_keys { "#{attributes_key}.#{it}" }
    end

    translations = permitted_translations(translations_param, NAME_TRANSLATED_ATTRIBUTES)
    record.assign_attributes(attributes)
    assign_translations(record, translations)

    if translations.size > 1
      MachineTranslation.suppress { record.save! }
    else
      record.save!
    end
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::BudgetPhase.find(params[:projekt_phase_id])
  end

  def find_budget
    @budget = Budget.includes(BudgetSerializer::PRELOADS).find(params[:id])
  end
end
