class Adm::MunicipalPlans::ProjektConversionsController < Adm::MunicipalPlans::BaseController
  before_action :find_municipal_plan

  def new
    @conversion = MunicipalPlan::ProjektConversion.prefilled_for(@municipal_plan)
    set_breadcrumbs
  end

  def create
    @conversion = MunicipalPlan::ProjektConversion.new(@municipal_plan, conversion_params)

    if @conversion.save(author: current_user)
      redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan), notice: t(".success")
    else
      set_breadcrumbs
      render :new, status: :unprocessable_entity
    end
  end

  private

    def find_municipal_plan
      @municipal_plan = MunicipalPlan.find(params[:municipal_plan_id])
      authorize @municipal_plan, :convert?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy
    end

    def conversion_params
      params.require(:municipal_plan_projekt_conversion).permit(:name, :subtitle)
    end

    def set_breadcrumbs
      @breadcrumbs = [
        { name: t("adm.municipal_plans.municipal_plans.index.title"),
          url: adm_municipal_plans_root_path, icon: "assignment" },
        { name: @municipal_plan.title, url: adm_municipal_plans_municipal_plan_path(@municipal_plan) },
        { name: t("adm.municipal_plans.projekt_conversions.new.title") }
      ]
    end
end
