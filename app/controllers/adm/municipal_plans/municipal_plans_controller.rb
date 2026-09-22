class Adm::MunicipalPlans::MunicipalPlansController < Adm::MunicipalPlans::BaseController
  include MapLocationAttributes

  before_action :find_municipal_plan, only: [:show, :edit, :update, :destroy, :submit, :release,
                                             :archive, :unarchive]
  before_action :redirect_to_working_copy, only: [:edit, :update]

  def index
    authorize MunicipalPlan, :index?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    set_header_options

    @pagy, @municipal_plans = pagy(
      Adm::MunicipalPlansQuery.new(
        scoped_plans.released_versions.includes(:responsible, :topics, :districts), params
      ).call
    )

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
    @municipal_plan.responsible = resolve_responsible || current_user.municipal_plan_officer
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

  def order
    authorize MunicipalPlan, :reorder?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    @municipal_plans = orderable_plans.includes(:responsible, :topics, :districts)
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def reorder
    authorize MunicipalPlan, :reorder?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    MunicipalPlan.apply_editorial_order(ordered_ids)
    head :ok
  end

  def submit
    if nothing_to_release?
      return redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan),
                         alert: t(".no_changes")
    end

    @municipal_plan.submitted_at = Time.current

    if @municipal_plan.save
      ::MunicipalPlans::SubmissionNotificationService.call(@municipal_plan)
      redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.municipal_plans.edit.title"))
      render :edit
    end
  end

  def release
    @municipal_plan.submitted_at ||= Time.current

    if @municipal_plan.valid?
      released = ::MunicipalPlans::ReleaseService.call(@municipal_plan)
      redirect_to adm_municipal_plans_municipal_plan_path(released), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.municipal_plans.edit.title"))
      render :edit
    end
  end

  def archive
    change_status("archived")
  end

  # A Vorhaben that was released before returns to the public list as it was, without a new
  # release; one that never left Entwurf goes back to being an Entwurf.
  def unarchive
    change_status(@municipal_plan.major_version.zero? ? "draft" : "published")
  end

  private

    def set_header_options
      @title_header_options = { search: true }
      @status_header_options = { sort: true, filter_options: status_filter_options }
      @responsible_header_options = { filter_options: responsible_filter_options }
      @districts_header_options = { filter_options: district_filter_options }
      @topics_header_options = { filter_options: topic_filter_options }
      @content_updated_at_header_options = { sort: true, date_range: true }
      @version_header_options = { sort: true }
    end

    def status_filter_options
      MunicipalPlan::STATUSES.index_with { |status| t("adm.municipal_plans.statuses.#{status}") }
    end

    def responsible_filter_options
      groups = MunicipalPlan::OfficerGroup.order(:name).map { |g| ["OfficerGroup:#{g.id}", g.name] }
      officers = MunicipalPlan::Officer.includes(:user).map { |o| ["Officer:#{o.id}", o.name] }

      (groups + officers.sort_by(&:last)).to_h
    end

    def district_filter_options
      RegisteredAddress::District.order(:name).to_h { |d| [d.id.to_s, d.name] }
    end

    def topic_filter_options
      MunicipalPlan::Topic.all.to_h { |topic| [topic.id.to_s, topic.name] }
    end

    # The archive keeps an order of its own, so it is left out of the editorial list.
    def orderable_plans
      scoped_plans.released_versions.where.not(status: "archived").sorted
    end

    # The submitted order decides, but only for Vorhaben this user may reorder at all.
    def ordered_ids
      submitted = Array(params[:tree]).map { |item| item[:id].to_s }
                                      .select { |id| id.match?(/\A\d+\z/) }
                                      .map(&:to_i)

      submitted & orderable_plans.ids
    end

    def nothing_to_release?
      @municipal_plan.working_copy? &&
        ::MunicipalPlans::ChangeSummaryService.call(@municipal_plan).empty?
    end

    # Content of a released Vorhaben is never edited in place: the form always works on the copy.
    def redirect_to_working_copy
      return if @municipal_plan.draft?

      redirect_to edit_adm_municipal_plans_municipal_plan_path(
        ::MunicipalPlans::WorkingCopyService.call(@municipal_plan)
      )
    end

    def change_status(status)
      if @municipal_plan.update(status: status)
        redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan), notice: t(".success")
      else
        redirect_to adm_municipal_plans_municipal_plan_path(@municipal_plan),
                    alert: @municipal_plan.errors[:base].to_sentence
      end
    end

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
        :given_order,
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
