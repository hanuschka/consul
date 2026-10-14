class Adm::MunicipalPlans::ProcedureStepsController < Adm::MunicipalPlans::BaseController
  before_action :ensure_procedure_steps_enabled

  def index
    authorize MunicipalPlan::ProcedureStep, :index?, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    @procedure_steps = policy_scope(
      MunicipalPlan::ProcedureStep,
      policy_scope_class: Adm::MunicipalPlans::ProcedureStepPolicy::Scope
    )

    @breadcrumbs = [
      { name: t("adm.municipal_plans.menu.items.procedure_steps"), icon: "format_list_numbered" }
    ]
  end

  def new
    @procedure_step = MunicipalPlan::ProcedureStep.new
    authorize @procedure_step, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @procedure_step = MunicipalPlan::ProcedureStep.find(params[:id])
    authorize @procedure_step, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @procedure_step = MunicipalPlan::ProcedureStep.new(procedure_step_params)
    authorize @procedure_step, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    if @procedure_step.save
      redirect_to adm_municipal_plans_procedure_steps_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.procedure_steps.new.title"))
      render :new
    end
  end

  def update
    @procedure_step = MunicipalPlan::ProcedureStep.find(params[:id])
    authorize @procedure_step, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    if @procedure_step.update(procedure_step_params)
      redirect_to adm_municipal_plans_procedure_steps_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.procedure_steps.edit.title"))
      render :edit
    end
  end

  def destroy
    @procedure_step = MunicipalPlan::ProcedureStep.find(params[:id])
    authorize @procedure_step, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    if @procedure_step.destroy
      redirect_to adm_municipal_plans_procedure_steps_path, notice: t(".success")
    else
      redirect_to adm_municipal_plans_procedure_steps_path, alert: t(".cannot_destroy")
    end
  end

  def order_procedure_steps
    authorize MunicipalPlan::ProcedureStep, :update?, policy_class: Adm::MunicipalPlans::ProcedureStepPolicy

    MunicipalPlan::ProcedureStep.order_procedure_steps(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def ensure_procedure_steps_enabled
      head :not_found unless MunicipalPlan.procedure_steps_enabled?
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.municipal_plans.procedure_steps.index.title"),
          url: adm_municipal_plans_procedure_steps_path, icon: "format_list_numbered" },
        { name: action_title }
      ]
    end

    def procedure_step_params
      params.require(:municipal_plan_procedure_step).permit(:name)
    end
end
