class Adm::Projekts::BudgetInvestmentsController < Adm::Projekts::BaseController
  include ImageAttributes
  include MapLocationAttributes
  include DocumentAttributes

  before_action :set_projekt_phase
  before_action :set_investment, only: %i[show administer edit update destroy audits]
  before_action :set_tabs, only: %i[show administer edit audits]

  def show
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    respond_to do |format|
      format.html do
        @image_url = @investment.image&.attachment&.variant(
          resize_to_limit: [500, 500],
          format: "jpeg"
        )

        @breadcrumbs = breadcrumbs_for_action(@investment.title)
      end
      format.pdf do
        pdf_content = PdfServices::BudgetInvestmentExporter.call(@investment)
        send_data pdf_content.render, filename: "budget_investment_#{@investment.id}.pdf", type: "application/pdf"
      end
    end
  end

  def audits
    authorize [:adm, :projekts, @investment], :show?, policy_class: Adm::Projekts::BudgetPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def administer
    authorize [:adm, :projekts, @investment], :update?, policy_class: Adm::Projekts::BudgetPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    @investment.build_image(user: current_user) unless @investment.image
    @investment.create_map_location unless @investment.map_location
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @investment], policy_class: Adm::Projekts::BudgetPolicy

    if @investment.update(investment_params)
      redirect_to adm_projekts_phase_budget_investment_path(@projekt_phase, @investment), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.budget_investments.edit.title"))
      render :edit, status: :unprocessable_entity
    end
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
      @investment = @projekt_phase.budget.investments.find(params[:id])
    end

    def investment_params
      params.require(:budget_investment).permit(
        :title, :description, :heading_id,
        :price, :price_first_year, :duration, :feasibility, :selected, :winner, :incompatible,
        :visible_to_valuators, :valuator_explanation, :valuation_finished,
        :video_url, :on_behalf_of,
        :implementation_performer, :implementation_contribution,
        :user_cost_estimate, :sentiment_id,
        projekt_label_ids: [],
        image_attributes: image_attributes,
        map_location_attributes: map_location_attributes,
        documents_attributes: [document_attributes]
      )
    end

    def set_tabs
      @tabs = %w[show administer audits].map do |tab_action|
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
        { name: t("adm.menu.items.projekts"), url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.budget_investments.title"), url: budget_investments_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
