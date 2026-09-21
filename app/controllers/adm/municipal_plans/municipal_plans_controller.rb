class Adm::MunicipalPlans::MunicipalPlansController < Adm::MunicipalPlans::BaseController
  include MapLocationAttributes

  before_action :find_municipal_plan, only: [:show, :edit, :update, :destroy]

  def index
    authorize MunicipalPlan, :index?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    @pagy, @municipal_plans = pagy(scoped_plans.includes(:responsible, :topics, :districts).sorted)

    @breadcrumbs = [{ name: t("adm.municipal_plans.menu.items.municipal_plans"), icon: "assignment" }]
  end

  def show
    @breadcrumbs = breadcrumbs_for_action(@municipal_plan.title)
  end

  def new
    @municipal_plan = MunicipalPlan.new
    @municipal_plan.build_map_location
    authorize @municipal_plan, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @municipal_plan = MunicipalPlan.new(municipal_plan_params)
    @municipal_plan.responsible = resolve_responsible
    authorize @municipal_plan, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    if @municipal_plan.save
      redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.municipal_plans.new.title"))
      render :new
    end
  end

  def update
    @municipal_plan.responsible = resolve_responsible if params.key?(:responsible)
    associations_before = association_fingerprint

    if @municipal_plan.update(municipal_plan_params)
      version_advanced = @municipal_plan.saved_change_to_version?

      if !version_advanced && association_fingerprint(reload: true) != associations_before
        @municipal_plan.register_content_change!
      end

      redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.municipal_plans.edit.title"))
      render :edit
    end
  end

  def destroy
    @municipal_plan.destroy!
    redirect_to adm_municipal_plans_root_path, notice: t(".success")
  end

  private

    def find_municipal_plan
      @municipal_plan = scoped_plans.find(params[:id])
      authorize @municipal_plan, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy
    end

    def scoped_plans
      policy_scope(MunicipalPlan, policy_scope_class: Adm::MunicipalPlans::MunicipalPlanPolicy::Scope)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.municipal_plans.municipal_plans.index.title"),
          url: adm_municipal_plans_root_path, icon: "assignment" },
        { name: action_title }
      ]
    end

    # Districts, topics and links are content fields too, but they change through associations, so
    # they never reach the record's own dirty tracking and cannot advance the Versionsnummer there.
    # Comparing a snapshot either side of the save catches them whichever way Rails applies them.
    def association_fingerprint(reload: false)
      plan = reload ? @municipal_plan.reload : @municipal_plan

      [
        plan.district_ids.sort,
        plan.topic_ids.sort,
        plan.links.map { |link| [link.id, link.title, link.url, link.given_order] }.sort_by(&:first)
      ]
    end

    def resolve_responsible
      return nil if params[:responsible].blank?

      type, id = params[:responsible].split(":")
      case type
      when "OfficerGroup" then MunicipalPlan::OfficerGroup.find(id)
      when "Officer" then MunicipalPlan::Officer.find(id)
      end
    end

    def municipal_plan_params
      params.require(:municipal_plan).permit(
        :status, :given_order,
        :formal_participation, :informal_participation,
        :contact_name, :contact_phone, :contact_email,
        :system_mailbox_email, :internal_notes,
        :title, :short_description, :further_information, :last_resolution,
        :processing_status, :next_steps, :costs,
        :formal_participation_reason, :informal_participation_reason, :contact_role,
        district_ids: [],
        topic_ids: [],
        links_attributes: [:id, :title, :url, :given_order, :_destroy],
        map_location_attributes: map_location_attributes
      )
    end
end
