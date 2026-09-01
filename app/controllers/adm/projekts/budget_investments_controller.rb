class Adm::Projekts::BudgetInvestmentsController < Adm::Projekts::BaseController
  include ImageAttributes
  include MapLocationAttributes
  include DocumentAttributes

  before_action :set_projekt_phase
  before_action :set_investment, only: %i[show administer people edit update frame_update destroy milestones progress_bars audits toggle_image_concealed]
  before_action :set_tabs, only: %i[show administer people edit update milestones progress_bars audits toggle_image_concealed]

  def show
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    respond_to do |format|
      format.html do
        @image_url = @investment.image&.attachment_variant(
          resize_to_limit: [500, 500],
          format: "jpeg"
        )

        @breadcrumbs = breadcrumbs_for_action(@investment.title)
        @similar_contributions = ::SimilarContributions::FindForProjekt.call(@investment)
      end
      format.pdf do
        pdf_content = PdfServices::BudgetInvestmentExporter.call(@investment, @projekt_phase)
        send_data pdf_content.render, filename: "budget_investment_#{@investment.id}.pdf", type: "application/pdf"
      end
    end
  end

  def milestones
    authorize [:adm, :projekts, @investment], :show?, policy_class: Adm::Projekts::BudgetPolicy

    @milestones = @investment.milestones.order_by_publication_date
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def progress_bars
    authorize [:adm, :projekts, @investment], :show?, policy_class: Adm::Projekts::BudgetPolicy

    @progress_bars = @investment.progress_bars
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def audits
    authorize [:adm, :projekts, @investment], :show?, policy_class: Adm::Projekts::BudgetPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def administer
    authorize [:adm, :projekts, @investment], :update?, policy_class: Adm::Projekts::BudgetPolicy

    redirect_to adm_projekts_phase_budget_investment_path(@projekt_phase, @investment)
  end

  def people
    authorize [:adm, :projekts, @investment], :update?, policy_class: Adm::Projekts::BudgetPolicy

    @budget = @projekt_phase.budget
    @admins = @budget.administrators.includes(:user)
    @valuators = @budget.valuators.includes(:user).order("users.email ASC")
    @valuator_groups = ValuatorGroup.all.order(name: :asc)
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    unless turbo_frame_request?
      redirect_to adm_projekts_phase_budget_investment_path(@projekt_phase, @investment)
      return
    end

    @investment.build_image(user: current_user) unless @investment.image
    @investment.create_map_location unless @investment.map_location
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  ADMIN_FORM_EDITORS = %w[feasibility pricing selection winner].freeze

  def update
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    success = @investment.update(investment_params)

    # A nested image `_destroy` leaves the destroyed record cached on the
    # association, so the re-rendered show_content would show a broken image
    # until a full reload. Reset it so the partial reflects the saved state.
    @investment.association(:image).reset if success

    if ADMIN_FORM_EDITORS.include?(params[:editor])
      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@investment, :admin_forms),
        partial: "adm/projekts/budget_investments/admin_forms",
        locals: {
          investment: @investment,
          projekt_phase: @projekt_phase,
          saved_editor: success ? params[:editor] : nil
        }
      )
      return
    end

    if success
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("investment_content",
              partial: "adm/projekts/budget_investments/show_content",
              locals: { investment: @investment, projekt_phase: @projekt_phase }
            ),
            turbo_stream.append("flash-messages", html:
              helpers.content_tag(:div, class: "kern-flash kern-flash--success", role: "alert") do
                helpers.content_tag(:span, t("adm.attribute.update.success")) +
                helpers.button_tag(type: "button", class: "kern-flash__close", aria: { label: "Close" }, onclick: "this.parentElement.remove()") do
                  helpers.content_tag(:span, "close", class: "material-symbols-outlined")
                end
              end
            )
          ]
        end
        format.html do
          redirect_to adm_projekts_phase_budget_investment_path(@projekt_phase, @investment), notice: t(".success")
        end
      end
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.budget_investments.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def frame_update
    authorize [:adm, :projekts, @investment], :update?, policy_class: Adm::Projekts::BudgetPolicy

    if @investment.update(investment_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    partial_name = turbo_frame_request_id.delete_prefix("investment_")
    budget = @projekt_phase.budget

    render turbo_stream: turbo_stream.replace(
      turbo_frame_request_id,
      partial: "adm/projekts/budget_investments/people/#{partial_name}",
      locals: {
        investment: @investment,
        projekt_phase: @projekt_phase,
        admins: budget.administrators.includes(:user),
        valuators: budget.valuators.includes(:user).order("users.email ASC"),
        valuator_groups: ValuatorGroup.all.order(name: :asc)
      }
    )
  end

  def hide
    @investment = @projekt_phase.budget.investments.find(params[:id])
    authorize [:adm, :projekts, @investment], :hide?, policy_class: Adm::Projekts::BudgetPolicy

    @investment.hide
    Activity.log(current_user, :hide, @investment)
    @investment.reload
  end

  def unhide
    @investment = @projekt_phase.budget.investments.with_hidden.find(params[:id])
    authorize [:adm, :projekts, @investment], :unhide?, policy_class: Adm::Projekts::BudgetPolicy

    @investment.restore
    Activity.log(current_user, :restore, @investment)
    @investment.reload
  end

  def ignore_flag
    @investment = @projekt_phase.budget.investments.find(params[:id])
    authorize [:adm, :projekts, @investment], :ignore_flag?, policy_class: Adm::Projekts::BudgetPolicy

    @investment.ignore_flag
    @investment.reload
  end

  def toggle_image_concealed
    authorize [:adm, :projekts, @investment], :update?, policy_class: Adm::Projekts::BudgetPolicy

    @investment.image.toggle!(:concealed)

    redirect_to adm_projekts_phase_budget_investment_path(@projekt_phase, @investment)
  end

  def destroy
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    @investment.destroy!
    redirect_to budget_investments_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_investment
      @investment = @projekt_phase.budget.investments.with_hidden.find(params[:id])
    end

    def investment_params
      params.require(:budget_investment).permit(
        :title, :description, :heading_id,
        :price, :price_first_year, :duration, :feasibility, :selected, :winner, :incompatible,
        :visible_to_valuators, :valuator_explanation, :valuation_finished,
        :video_url, :on_behalf_of,
        :implementation_performer, :implementation_contribution,
        :user_cost_estimate, :sentiment_id,
        :administrator_id,
        projekt_label_ids: [],
        valuator_ids: [],
        valuator_group_ids: [],
        image_attributes: image_attributes,
        map_location_attributes: map_location_attributes,
        documents_attributes: [document_attributes]
      )
    end

    def set_tabs
      @tabs = %w[show people milestones progress_bars audits].map do |tab_action|
        {
          label: t("adm.projekts.budget_investments.tabs.#{tab_action}"),
          url: send(
            "#{tab_action == 'show' ? '' : "#{tab_action}_"}adm_projekts_phase_budget_investment_path",
            @projekt_phase,
            @investment
          ),
          current: action_name == tab_action
        }
      end
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.budget_investments.title"), url: budget_investments_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
