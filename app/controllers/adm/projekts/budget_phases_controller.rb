class Adm::Projekts::BudgetPhasesController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_budget_phase

  def edit
    authorize [:adm, :projekts, @budget_phase], policy_class: Adm::Projekts::BudgetPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def toggle_enabled
    authorize [:adm, :projekts, @budget_phase], :update?, policy_class: Adm::Projekts::BudgetPolicy
    @budget_phase.update!(enabled: !@budget_phase.enabled?)
    @budget_phases = @projekt_phase.budget.phases.order(:id).reload
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_budget_phase
      @budget_phase = @projekt_phase.budget.phases.find(params[:id])
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.budget_phases.title"), url: budget_phases_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
